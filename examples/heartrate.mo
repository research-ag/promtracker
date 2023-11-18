import PT "../src";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Array "mo:base/Array";

import TinyHttp "tiny_http";

/// A canister, which answers by HTTP at route /metrics with statistics of interval between heartbeats in prometheus format
actor {
  // initialize the tracker
  let pt = PT.PromTracker("", 65);

  // register a gauge with 10 buckets (plus the +Inf bucket)
  // bucket limits: 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400
  let limits = Array.tabulate<Nat>(10, func(n) = 500 + n * 100);
  let my_gauge = pt.addGauge("time", limits);

  // update gauge in heartbeat
  // gauge value = time delta between last two heartbeats in milliseconds
  var last_time : ?Nat = null;
  system func heartbeat() : async () {
    let now = Int.abs(Time.now()) / 1000000;
    switch (last_time) {
      case (?last) my_gauge.update(now - last : Nat);
      case (_) {};
    };
    last_time := ?now;
  };

  // provide the "/metrics" endpoint
  public query func http_request(req : TinyHttp.Request) : async TinyHttp.Response {
    let ?path = Text.split(req.url, #char '?').next() else return TinyHttp.render400();
    switch (req.method, path) {
      case ("GET", "/metrics") TinyHttp.renderPlainText(pt.renderExposition());
      case (_) TinyHttp.render400();
    };
  };

};
