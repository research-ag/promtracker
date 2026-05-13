/// Hierarchical metric tracking.
///
/// This module provides the `Tracker` type, which allows for hierarchical
/// organization of metrics. Trackers can contain counters, gauges, heatmaps,
/// and other nested trackers.
///
/// ```motoko name=import
/// import Tracker "mo:promtracker/Tracker";
/// ```

import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";
import Label "Label";
import Types "internal/Types";

module {
  /// Passthrough for `Metrics.Counter.Counter`.
  public type Counter = Types.Counter;

  /// Passthrough for `Metrics.Gauge.Gauge`.
  public type Gauge = Types.Gauge;

  /// Passthrough for `Metrics.Heatmap.Heatmap`.
  public type Heatmap = Types.Heatmap;

  /// The tracker state object.
  public type Tracker = Types.Tracker;

  /// Passthrough for `Metrics.Value`.
  public type Value = Metrics.Value;

  /// Returns a `canister="id"` label for the given actor.
  public func canisterLabel(a : actor {}) : Label.Label = Label.canisterLabel(a);

  // Value variant type
  private func readValue(val : Types.TValue) : [Metrics.Metric] {
    switch val {
      case (#counter ctr) { Metrics.Counter.value(ctr).read() };
      case (#gauge g) { Metrics.Gauge.value(g).read() };
      case (#heatmap h) { Metrics.Heatmap.value(h).read() };
      case (#tracker t) { t.read() };
    };
  };

  // Watermark environment
  func nanos(seconds : Nat) : Nat64 = seconds.toNat64() * 1_000_000_000;

  /// Creates a new top-level tracker with default settings.
  ///
  /// Default hold-down period is 302 seconds.
  public func new() : Tracker {
    let tracker : Tracker = {
      parent = null;
      var labels = "";
      var values = List.empty();
      env = { var holdDownPeriod = nanos(302) };
      var nonce = 0;
      id = 0;
    };
    tracker;
  };
  /// Creates a new top-level tracker with specific labels and hold-down period.
  ///
  /// Traps if `labels_` contains invalid label names.
  public func newWith(
    labels_ : [Label.Label],
    seconds : Nat,
  ) : Tracker {
    let tracker : Tracker = {
      parent = null;
      var labels = Label.renderLabels(labels_);
      var values = List.empty();
      env = { var holdDownPeriod = nanos(seconds) };
      var nonce = 0;
      id = 0;
    };
    tracker;
  };

  /// Updates the hold-down period for all gauges in this tracker and its children.
  public func setHoldDown(self : Tracker, seconds : Nat) {
    self.env.holdDownPeriod := nanos(seconds);
  };
  /// Sets the labels for the tracker.
  ///
  /// Traps if `labels` contains invalid label names.
  public func setLabels(self : Tracker, labels : [Label.Label]) {
    self.labels := Label.renderLabels(labels);
  };
  /// Adds a single label to the tracker.
  ///
  /// Traps if `key` is an invalid label name.
  public func addLabel(self : Tracker, key : Text, value : Text) {
    self.labels := Label.concat(self.labels, Label.renderLabel(key, value));
  };
  /// Adds a `canister="id"` label to the tracker for the given actor.
  public func addCanisterLabel(self : Tracker, a : actor {}) {
    let (k, v) = Label.canisterLabel(a);
    addLabel(self, k, v);
  };
  /// Creates and registers a new counter in this tracker.
  ///
  /// Traps if `labels` contains invalid label names.
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter {
    let labelStr = Label.renderLabels(labels);
    let newCounter = Metrics.Counter.new(self, name, labelStr, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#counter newCounter);
    newCounter;
  };
  /// Creates and registers a new gauge in this tracker.
  ///
  /// Traps if:
  /// - `labels` contains invalid label names,
  /// - `limits` are not strictly increasing.
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge {
    let labelStr = Label.renderLabels(labels);
    let newGauge = Metrics.Gauge.new(self, prefix, labelStr, self.env, limits, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#gauge newGauge);
    newGauge;
  };
  /// Creates and registers a new heatmap in this tracker.
  ///
  /// Traps if `labels` contains invalid label names.
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap {
    let labelStr = Label.renderLabels(labels);
    let newHeatmap = Metrics.Heatmap.new(self, prefix, labelStr, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#heatmap newHeatmap);
    newHeatmap;
  };
  /// Creates and registers a new nested tracker.
  ///
  /// Traps if `labels` contains invalid label names.
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
  /// Unregisters the tracker from its parent.
  public func unregister(self : Tracker) {
    let ?parent = self.parent else return;
    parent.values := parent.values.filter(
      func(v) = switch v {
        case (#tracker t) { t.id != self.id };
        case (_) true;
      }
    );
  };

  /// Returns all metrics tracked by this tracker and its children.
  public func read(self : Tracker) : [Metrics.Metric] {
    let all = self.values.map(func(v) = readValue(v)).reverse().toArray().flatten();
    all.map(func(m) = m.prependLabels(self.labels));
  };

  /// Converts the tracker to a `Value` interface for use with a `Renderer`.
  public func toValue(self : Tracker) : Metrics.Value = {
    read = func() = self.read();
  };

  /// Renders all metrics in the tracker to Prometheus exposition format.
  public func renderExposition(self : Tracker) : Text {
    let timeStr = (Prim.time() / 1_000_000).toText();
    read(self).map(
      func(m) = m.render(timeStr)
    ).vals().join("");
  };

  /// Returns a function that renders the tracker's exposition.
  public func renderFunction(self : Tracker) : () -> Text {
    func() = self.renderExposition();
  };

  /// Returns a function that reads the tracker's metrics.
  public func readFunction(self : Tracker) : () -> [Metrics.Metric] {
    func() = self.read();
  };

};
