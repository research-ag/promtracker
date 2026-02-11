import Array "mo:core/Array";
import Nat64_ "mo:core/Nat64";
import Prim "mo:prim";
import Prng "mo:prng";

import PromTracker "../../src/mixins/tracker";
import Http "../../src/mixins/http";
import Util "../../src";
// In production:
// import PromTracker "mo:promtracker/mixins/tracker";
// import Http "mo:promtracker/mixins/http";
// import Util "mo:promtracker";

/// A canister, which exposes Prometheus metrics via HTTP at route `/metrics`
/// It provides the following metrics:
///
/// - instructions: a gauge of the cycles used to parse the last call arguments
/// - bytes: a gauge of the size of the last call arguments
persistent actor Main {
  // The second argument `false` disables the default set of system metrics
  // which were already shown in the `minimal` example.
  include PromTracker(Main);
  include Http(pt, "/metrics");

  // If we are not exclusively using PullValues then we need this:
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

  // Example of a Gauge: instructions used to pass the last call arguments
  // Register a gauge with 5 buckets (plus the +Inf bucket)
  // Bucket limits are: 6000, 7000, 8000, 9000, 10000
  // Argument `false` means that the gauge is reset on canister upgrade
  transient let instrGauge = pt.addGauge("instructions", [], #both, Util.limits(5000, 5, 1000), false);

  // Example of a Gauge: size of the last call arguments
  // Register a gauge with 10 buckets (plus the +Inf bucket)
  // Bucket limits are: 10, .., 100
  // Argument `false` means that the gauge is reset on canister upgrade
  transient let sizeGauge = pt.addGauge("bytes", [], #both, Util.limits(0, 10, 10), false);

  // We make random calls to the following function and measure:
  // - instructions for candid parsing of the arguments
  // - size of the candid encoded arguments
  public func foo(arg : [Nat64]) : () {
    instrGauge.update(Prim.performanceCounter(0).toNat());
    let b = to_candid (arg);
    sizeGauge.update(b.size());
  };

  // Random number generator for generating random arguments for foo()
  transient let rng = Prng.Seiran128();
  rng.init(0);

  // We update a gauge in heartbeat
  // gauge value = time delta between last two heartbeats in milliseconds
  system func heartbeat() : async () {
    // once every 4 heartbeats call foo with a random-length argument
    if (rng.next() % 4 != 0) return;
    let len = (rng.next() % 6 + rng.next() % 6).toNat();
    foo(Array.tabulate<Nat64>(len, func(n) = rng.next()));
  };

};
