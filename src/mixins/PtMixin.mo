import PT "../";

mixin(self : actor {}, withSystemValues : Bool) {
  transient let pt = PT.PromTracker(PT.canisterLabel(self), 65);
  var ptStableData = pt.share();

  if (withSystemValues) pt.addSystemValues();

  // Expose the `/metrics` endpoint
  public query func http_request(req : PT.HttpReq) : async PT.HttpResp {
    pt.http_request(req);
  };

  func pt_preupgrade() = ptStableData := pt.share();
  func pt_postupgrade() = pt.unshare(ptStableData);
};
