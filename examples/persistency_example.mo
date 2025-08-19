import Cycles "mo:base/ExperimentalCycles";
import Prim "mo:prim";
import Text "mo:base/Text";

import PT "../src";
import Http "tiny_http";

/// This canister shows how to setup the metrics to preserve values through the canister upgrades
persistent actor class Main() = self {

  // a stable variable which will store metrics states
  var ptData : PT.StableData = null;

  transient let pt = PT.PromTracker("", 65);

  system func postupgrade() {
    // this must be called after all the metrics were added to the promtracker. Otherwise stable data will be ignored
    pt.unshare(ptData);
  };

  system func preupgrade() {
    ptData := pt.share();
  };

  // pull values can not be stable as they do not store any data
  ignore pt.addPullValue("cycles", "", Cycles.balance);

  // counter, that will be reset on each upgrade
  transient let counter0 = pt.addCounter("counter", "is_stable=\"false\"", false);
  // counter, that will be preserved through upgrades
  transient let counter1 = pt.addCounter("counter", "is_stable=\"true\"", true);

  // same for gauges:
  transient let gauge0 = pt.addGauge("gauge", "is_stable=\"false\"", #both, PT.limits(0, 10, 10), false);
  transient let gauge1 = pt.addGauge("gauge", "is_stable=\"true\"", #both, PT.limits(0, 10, 10), true);

  // and heatmaps:
  transient let heatmap0 = pt.addHeatmap("heatmap", "is_stable=\"false\"", false);
  transient let heatmap1 = pt.addHeatmap("heatmap", "is_stable=\"true\"", true);

  public func incCounter(n : Nat) : () {
    counter0.add(n);
    counter1.add(n);
  };

  public func addToHeatmap(v : Nat) : () {
    heatmap0.addEntry(v);
    heatmap1.addEntry(v);
  };

  transient var last_time : ?Nat = null;
  system func heartbeat() : async () {
    let now = Prim.nat64ToNat(Prim.time() / 1000000);
    switch (last_time) {
      case (?last) {
        gauge0.update(now - last : Nat);
        gauge1.update(now - last : Nat);
      };
      case (_) {};
    };
    last_time := ?now;
  };

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
