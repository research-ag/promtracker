/// Restricted Prometheus Tracker API.
///
/// This module provides a subset of `Tracker` functionality, allowing components
/// to register metrics and sub-trackers while restricting access to administrative
/// operations like setting hold-down periods or rendering the final exposition.
///
/// Components should generally import this module to interact with a `Tracker`
/// instance passed from a parent.
///
/// ```motoko name=import
/// import TrackerAPI "mo:promtracker/TrackerAPI";
/// ```

import List "mo:core/pure/List";
import Metrics "Metrics";
import Label "Label";
import Types "internal/Types";

import Tracker "Tracker";

module {
  // Type passthrough
  public type Counter = Types.Counter;
  public type Gauge = Types.Gauge;
  public type Heatmap = Types.Heatmap;
  public type Tracker = Types.Tracker;

  public func addLabel(self : Tracker, key : Text, value : Text) = self.addLabel(key, value);

  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter = self.newCounter(name, labels);
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge = self.newGauge(prefix, labels, limits);
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap = self.newHeatmap(prefix, labels);
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker = self.newTracker(labels);
  public func unregister(self : Tracker) = self.unregister();
};
