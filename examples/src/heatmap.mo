import Int "mo:core/Int";
import Time "mo:core/Time";
import PromTracker "../../src/mixins/default";
// In production:
// import PromTracker "mo:promtracker/mixins/default";

/// This canister shows how to setup the metrics to preserve values through the canister upgrades
persistent actor Main {
  include PromTracker(Main, false);
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

  // Heatmap
  transient let heatmap = pt.addHeatmap("heatmap", "", true);

  transient var last_time : ?Int = null;
  system func heartbeat() : async () {
    let now = Time.now() / 1_000_000;
    switch (last_time) {
      case (?last) {
        let v : Nat = Int.abs(now - last);
        heatmap.addEntry(v);
      };
      case (_) {};
    };
    last_time := ?now;
  };
};
