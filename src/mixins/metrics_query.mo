import PT "../";

/// Mixin that adds query interface to Prometheus metrics
/// Defines:
///
/// * public query func pt_metrics() : async PT.Exposition
///
/// Arguments:
///
/// * pt: PromTracker class from which to generate metrics
mixin(pt : PT.PromTracker) {
  public query func pt_metrics() : async PT.Exposition = async pt.getExposition();
};
