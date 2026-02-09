import Http "../../src/mixins/http";
import PT "../../src";
// In production use this instead:
// import Http "mo:promtracker/mixins/http";
// import PT "mo:promtracker";

// This example shows how to use PromTracker in plain mode, without mixins.

persistent actor Main {
  transient let pt = PT.PromTracker(PT.canisterLabel(Main), 65);
  var ptStableData : PT.StableData = null;
  system func preupgrade() { ptStableData := pt.share() };
  system func postupgrade() { pt.unshare(ptStableData) };

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };

  include Http(pt);
};
