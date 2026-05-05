/// Shared API functions for Tracker and nested Trackers.
///
/// ```motoko name=import
/// import TrackerAPI "mo:promtracker/TrackerAPI";
/// ```

import List "mo:core/pure/List";
import Metrics "Metrics";
import Label "Label";
import Types "internal/Types";

module {
  /// Counter type passthrough.
  public type Counter = Types.Counter;
  /// Gauge type passthrough.
  public type Gauge = Types.Gauge;
  /// Heatmap type passthrough.
  public type Heatmap = Types.Heatmap;
  /// Tracker type passthrough.
  public type Tracker = Types.Tracker;

  /// Add a label to a tracker.
  public func addLabel(self : Tracker, key : Text, value : Text) {
    self.labels := Label.concat(self.labels, Label.renderLabel(key, value));
  };

  /// Create and register a new counter in a tracker.
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter {
    let labelStr = Label.renderLabels(labels);
    let newCounter = Metrics.Counter.new(self, name, labelStr, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#counter newCounter);
    newCounter;
  };

  /// Create and register a new gauge in a tracker.
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge {
    let labelStr = Label.renderLabels(labels);
    let newGauge = Metrics.Gauge.new(self, prefix, labelStr, self.env, limits, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#gauge newGauge);
    newGauge;
  };

  /// Create and register a new heatmap in a tracker.
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap {
    let labelStr = Label.renderLabels(labels);
    let newHeatmap = Metrics.Heatmap.new(self, prefix, labelStr, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#heatmap newHeatmap);
    newHeatmap;
  };

  /// Create and register a new nested tracker.
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker {
    let labelStr = Label.renderLabels(labels);
    let newTracker : Tracker = {
      parent = ?self;
      var labels = labelStr;
      var values = List.empty();
      env = self.env;
      var nonce = 0;
      id = self.nonce;
    };
    self.nonce += 1;
    self.values := self.values.pushFront(#tracker newTracker);
    newTracker;
  };

  /// Unregister a tracker from its parent.
  public func unregister(self : Tracker) {
    let ?parent = self.parent else return;
    parent.values := parent.values.filter(
      func(v) = switch v {
        case (#tracker t) { t.id != self.id };
        case (_) true;
      }
    );
  };
};
