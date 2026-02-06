import PT "../";

/// Mixin that adds Prometheus metrics endpoint
/// Defines:
/// 
/// * transient let pt : PT.PromTracker
/// * var pt_stableData : PT.StableData
/// * func pt_preupgrade() 
/// * func pt_postupgrade()
/// * public query func http_request(req : HttpReq) : async HttpResp
///
/// Arguments:
///
/// * self: the actor to which the mixin is applied, is used to derive a label with the canister id
/// * withSystemValues: if true, system values (CPU, memory, cycles) are added to the tracker
mixin(self : actor {}, withSystemValues : Bool) {
  transient let pt = PT.PromTracker(PT.canisterLabel(self), 65);
  var ptStableData : PT.StableData = null;

  if (withSystemValues) pt.addSystemValues();

  func pt_preupgrade() = ptStableData := pt.share();
  func pt_postupgrade() = pt.unshare(ptStableData);
  // Expose the `/metrics` endpoint
  public query func http_request(req : PT.HttpReq) : async PT.HttpResp {
    pt.http_request(req);
  };
};
