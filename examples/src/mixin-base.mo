import PromTracker "../../src/mixins/base";
// In production use this instead:
// import PromTracker "mo:promtracker/mixins/PtMixin";

// The `base` mixin does not define the public http_request function.
// We have to define it ourselves.

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

  // Expose the `/metrics` endpoint
  public query func http_request(req : HttpReq) : async HttpResp {
    pt.http_request(req);
  };

};