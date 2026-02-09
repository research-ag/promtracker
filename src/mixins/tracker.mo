import PT "../";

/// Mixin that adds Prometheus tracker (without metrics endpoint)
/// Defines:
/// 
/// * transient let pt : PT.PromTracker
/// * var ptStableData : PT.StableData
/// * func pt_preupgrade() 
/// * func pt_postupgrade()
///
/// Arguments:
///
/// * self: the actor to which the mixin is applied, is used to derive a label with the canister id
mixin(self : actor {}) {
  transient let pt = PT.PromTracker(PT.canisterLabel(self));
  var ptStableData : PT.StableData = null;

  func pt_preupgrade() = ptStableData := pt.share();
  func pt_postupgrade() = pt.unshare(ptStableData);
};
