import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Prim "mo:prim";
import Prng "mo:prng";
import Time "mo:base/Time";
import Text "mo:base/Text";

import PT "../src";
import Http "tiny_http";

/// A canister, which answers by HTTP at route /metrics with a statistics in Prometheus format
/// It provides the following metrics:
/// 
/// - time: a gauge of the time between heartbeats
/// - cycles: a pull value of the cycles balance
/// - instructions: a gauge of the cycles used to parse the last call arguments
/// - bytes: a gauge of the size of the last call arguments
actor class Main() = self {
  // initialize the tracker
  let pt = PT.PromTracker("", 65);

  // register a gauge with 10 buckets (plus the +Inf bucket)
  // bucket limits: 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600
  let limits = Array.tabulate<Nat>(12, func(n) = 500 + n * 100);
  let time_gauge = pt.addGauge("time", limits);

  // register a pull value for the cycle balance
  let cycle_balance = pt.addPullValue("cycles", Cycles.balance);

  // register a gauge for the cycles used to pass the last call arguments
  // For local deployment, use limits PT.limits(2200, 15, 100)
  // For mainnet deployment, use limits PT.limits(4600, 10, 100)
  let instructions_gauge = pt.addGauge("instructions", PT.limits(4600, 10, 200));

  // register a gauge for the cycles used to pass the last call arguments
  let size_gauge = pt.addGauge("bytes", PT.limits(0, 10, 10));

  // We make random calls to the following function and measure:
  // - instructions for candid parsing of the arguments
  // - size of the candid encoded arguments
  public func foo(arg : [Nat64]) : () {
    instructions_gauge.update(Nat64.toNat(Prim.performanceCounter(0)));
    let b = to_candid (arg);
    size_gauge.update(b.size());
  };

  // Random number generator for generating random arguments for foo()
  let rng = Prng.Seiran128();
  rng.init(0);

  // We update a gauge in heartbeat
  // gauge value = time delta between last two heartbeats in milliseconds
  var last_time : ?Nat = null;
  system func heartbeat() : async () {
    // determine time since last heartbeat and update gauge
    let now = Int.abs(Time.now()) / 1000000;
    switch (last_time) {
      case (?last) time_gauge.update(now - last : Nat);
      case (_) {};
    };
    last_time := ?now;

    // once every 4 heartbeats call foo with a random-length argument
    if (rng.next() % 4 != 0) return;
    let len = Nat64.toNat(rng.next() % 6 + rng.next() % 6);
    foo(Array.tabulate<Nat64>(len, func(n) = rng.next()));
  };

  // provide the "/metrics" endpoint
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = Text.split(req.url, #char '?').next() else return Http.render400();
    let labels = "canister=\"" # PT.shortName(self) # "\"";
    switch (req.method, path) {
      case ("GET", "/metrics") {
        Http.renderPlainText(pt.renderExposition(labels));
      };
      case (_) Http.render400();
    };
  };

};
