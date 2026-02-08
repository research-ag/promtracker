import PT "../";

/// Mixin that adds Prometheus tracker (without metrics endpoint)
/// Defines:
/// 
/// * transient let pt : PT.PromTracker
/// * var ptStableData : PT.StableData
/// * func pt_preupgrade() 
/// * func pt_postupgrade()
/// * module Http
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
};
