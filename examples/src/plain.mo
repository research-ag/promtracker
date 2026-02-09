import PT "../../src";
import Http "../../src/mixins/http";
// In production use this instead:
// import PT "mo:promtracker";
// import Http "mo:promtracker/mixins/http";

/// This example shows how to use PromTracker class without mixin.
persistent actor Main {
  transient let pt = PT.PromTracker(PT.canisterLabel(Main));
  include Http(pt, "/metrics");

  var ptStableData : PT.StableData = null;
  system func preupgrade() { ptStableData := pt.share() };
  system func postupgrade() { pt.unshare(ptStableData) };

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };
};
