import Int "mo:core/Int";
import Time "mo:core/Time";

import PromTracker "../../src/mixins/tracker";
import Http "../../src/mixins/http";
// In production:
// import PromTracker "mo:promtracker/mixins/tracker";
// import Http "mo:promtracker/mixins/http";

/// This canister shows how to use the `Heatmap` value.
persistent actor Main {
  include PromTracker(Main);
  include Http(pt, "/metrics");
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

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
