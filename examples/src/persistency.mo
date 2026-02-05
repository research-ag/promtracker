import Cycles "mo:core/Cycles";
import Nat64_ "mo:core/Nat64";
import Prim "mo:prim";
import PT "../../src";

/// This canister shows how to setup the metrics to preserve values through the canister upgrades
persistent actor Main {
  transient let pt = PT.PromTracker(PT.canisterLabel(Main), 65);

  // Persist stream state and metrics across upgrades
  var ptData = pt.share();
  system func preupgrade() = ptData := pt.share();
  system func postupgrade() = pt.unshare(ptData);

  // pull values can not be stable as they do not store any data
  ignore pt.addPullValue("cycles", "", Cycles.balance);

  // counter, that will be reset on each upgrade
  transient let counter0 = pt.addCounter("counter", "is_stable=\"false\"", false);
  // counter, that will be preserved through upgrades
  transient let counter1 = pt.addCounter("counter", "is_stable=\"true\"", true);

  // same for gauges:
  transient let gauge0 = pt.addGauge("gauge", "is_stable=\"false\"", #both, PT.limits(100, 10, 10), false);
  transient let gauge1 = pt.addGauge("gauge", "is_stable=\"true\"", #both, PT.limits(100, 10, 10), true);

  // and heatmaps:
  transient let heatmap0 = pt.addHeatmap("heatmap", "is_stable=\"false\"", false);
  transient let heatmap1 = pt.addHeatmap("heatmap", "is_stable=\"true\"", true);

  public func incCounter(n : Nat) {
    counter0.add(n);
    counter1.add(n);
  };

  public func addToHeatmap(v : Nat) {
    heatmap0.addEntry(v);
    heatmap1.addEntry(v);
  };

  transient var last_time : ?Nat = null;
  system func heartbeat() : async () {
    let now = (Prim.time() / 1000000).toNat();
    switch (last_time) {
      case (?last) {
        let v : Nat = now - last;
        gauge0.update(v);
        gauge1.update(v);
        heatmap0.addEntry(v);
        heatmap1.addEntry(v);
      };
      case (_) {};
    };
    last_time := ?now;
    counter0.add(1);
    counter1.add(1);
  };

  // Expose the `/metrics` endpoint
  public query func http_request(req : PT.HttpReq) : async PT.HttpResp {
    pt.http_request(req);
  };

};
