import PromTracker "../../src/mixins/base";
// In production use this instead:
// import PromTracker "mo:promtracker/mixins/base";

// The `base` mixin does not define the public http_request function.
// We have to define it ourselves.

persistent actor Main {
  include PromTracker(Main, false);
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };

  // Expose the `/metrics` endpoint
  public query func http_request(req : HttpReq) : async HttpResp {
    pt.http_request(req);
  };

};