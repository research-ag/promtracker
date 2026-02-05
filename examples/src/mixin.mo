import PromTracker "../../src/mixins/PtMixin";

// The mixin defines the public http_request function.
// If you want to define your own then you cannot use the mixin.

persistent actor Main {
  include PromTracker(Main, true); // defines `transient let pt`
  transient let counter1 = pt.addCounter("counter", "stable=true", true);
  transient let counter2 = pt.addCounter("counter", "stable=false", false);

  // Hook up pre/postupgrade
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

  system func heartbeat() : async () {
    counter1.add(1);
    counter2.add(1);
  };
};