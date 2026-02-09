import Cycles "mo:core/Cycles";
import Int "mo:core/Int";
import Time "mo:core/Time";

import Http "../../src/mixins/http";
import PromTracker "../../src/mixins/base";
// In production:
// import Http "mo:promtracker/mixins/http";
// import PromTracker "mo:promtracker/mixins/base";
import Util "../../src";

/// A canister, which exposes Prometheus metrics via HTTP at route `/metrics`
/// It provides the following metrics:
///
/// - cycles: a pull value of the cycles balance
/// - counter: a heartbeat counter 
/// - time: a gauge of the time between heartbeats
persistent actor Main {
  // The second argument `false` disables the default set of system metrics
  // which were already shown in the `minimal` example.
  include PromTracker(Main, false);
  include Http(pt);

  // If we are not exclusively using PullValues then we need this:
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

  // Example of a PullValue: cycle balance
  transient let _cycleBalance = pt.addPullValue("cycles", "", Cycles.balance);

  // Examples of Counters: heartbeat counters
  // First counter resets on canister upgrade
  // Second counter persists through upgrades, shows heartbeats since last reinstall
  transient let counter0 = pt.addCounter("heartbeats", "is_stable=\"false\"", false);
  transient let counter1 = pt.addCounter("heartbeats", "is_stable=\"true\"", true);

  // Example of a Gauge: time between heartbeats 
  // Register a gauge with 10 buckets (plus the +Inf bucket)
  // Bucket limits are: 110, 120, 130, .., 200 
  // Argument `#both` enables high and low watermarks for the gauge
  // Argument `true` means that the gauge persists across canister upgrade
  // Note that the bucket limits are chosen for local deployment. On mainnet
  // we would use larger values.
  transient let timeGauge = pt.addGauge("time", "", #both, Util.limits(100, 10, 10), true);

  // We update a gauge in heartbeat
  // gauge value = time delta between last two heartbeats in milliseconds
  transient var last_time : ?Int = null;
  system func heartbeat() : async () {
    // increment heartbeat counters
    counter0.add(1);
    counter1.add(1);

    // determine time since last heartbeat and update `timeGauge`
    let now = Time.now() / 1_000_000;
    switch (last_time) {
      case (?last) timeGauge.update(Int.abs(now - last));
      case (_) {};
    };
    last_time := ?now;
  };

};
