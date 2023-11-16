import PT "../src";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Text "mo:base/Text";

import TinyHttp "./tiny_http";

/// A canister, which answers by HTTP at route /metrics with statistics of interval between heartbeats in prometheus format
actor {
  // define a gauge
  let pt = PT.PromTracker(65);
  let my_gauge = pt.addGauge("time", null);

  // update gauge in heartbeat
  // gauge value = time delta between last two heartbeats
  var last_time : ?Nat = null;
  system func heartbeat() : async () {
    let now = Int.abs(Time.now());
    switch (last_time) {
      case (?t) my_gauge.update(now - t : Nat);
      case (_) {};
    };
    last_time := ?now;
  };

  // metrics endpoint
  public query func http_request(req : TinyHttp.Request) : async TinyHttp.Response {
    let ?path = Text.split(req.url, #char '?').next() else return TinyHttp.render400();
    switch (req.method, path) {
      case ("GET", "/metrics") TinyHttp.renderPlainText(pt.renderExposition());
      case (_) TinyHttp.render400();
    };
  };

};
