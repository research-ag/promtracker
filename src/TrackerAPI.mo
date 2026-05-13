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
  /// Passthrough for `Metrics.Counter.Counter`.
  public type Counter = Types.Counter;

  /// Passthrough for `Metrics.Gauge.Gauge`.
  public type Gauge = Types.Gauge;

  /// Passthrough for `Metrics.Heatmap.Heatmap`.
  public type Heatmap = Types.Heatmap;

  /// Passthrough for `Tracker.Tracker`.
  public type Tracker = Types.Tracker;

  /// Adds a single label to the tracker.
  ///
  /// Traps if `key` is an invalid label name.
  public func addLabel(self : Tracker, key : Text, value : Text) = self.addLabel(key, value);

  /// Creates and registers a new counter in this tracker.
  ///
  /// Traps if `labels` contains invalid label names.
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter = self.newCounter(name, labels);

  /// Creates and registers a new gauge in this tracker.
  ///
  /// Traps if:
  /// - `labels` contains invalid label names,
  /// - `limits` are not strictly increasing.
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge = self.newGauge(prefix, labels, limits);

  /// Creates and registers a new heatmap in this tracker.
  ///
  /// Traps if `labels` contains invalid label names.
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap = self.newHeatmap(prefix, labels);

  /// Creates and registers a new nested tracker.
  ///
  /// Traps if `labels` contains invalid label names.
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker = self.newTracker(labels);

  /// Unregisters the tracker from its parent.
  public func unregister(self : Tracker) = self.unregister();
};
