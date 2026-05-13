/// Main entry point for the Prometheus metric tracking library.
///
/// This module provides the `Renderer` class for top-level metric exposition
/// and re-exports the `Tracker` and metric types for convenience.
///
/// ```motoko name=import
/// import PromTracker "mo:promtracker";
/// ```

import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat64_ "mo:core/Nat64";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";
import T "Tracker";
import Label "Label";

module {
  /// A hierarchical metric tracker.
  ///
  /// Trackers allow for organizational grouping of metrics. A tracker can
  /// contain counters, gauges, heatmaps, and other nested trackers.
  ///
  /// Use `Tracker.new()` to create a top-level tracker.
  public type Tracker = T.Tracker;

  /// A cumulative, monotonically increasing counter.
  ///
  /// A counter is used to track values that only go up, such as the number of requests
  /// served or errors encountered.
  ///
  /// Use `Counter.add(counter, n)` to increase the value.
  public type Counter = Metrics.Counter.Counter;

  /// A numerical value that can arbitrarily go up and down.
  ///
  /// Gauges are typically used for measured values like temperature or current
  /// memory usage, but also "counts" that can go up and down, like the number of
  /// concurrent requests.
  ///
  /// Use `Gauge.update(gauge, value)` to set the current value.
  public type Gauge = Metrics.Gauge.Gauge;

  /// A histogram-like metric using power-of-2 buckets.
  ///
  /// Heatmaps track the distribution of values by counting them into buckets.
  /// This implementation uses automatic power-of-2 bucket boundaries.
  ///
  /// Use `Heatmap.add(heatmap, value)` to record a new observation.
  public type Heatmap = Metrics.Heatmap.Heatmap;

  /// Module for creating and managing trackers.
  public let Tracker = T;

  /// Module for creating and managing counter metrics.
  public let Counter = Metrics.Counter;

  /// Module for creating and managing gauge metrics.
  public let Gauge = Metrics.Gauge;

  /// Module for creating and managing heatmap metrics.
  public let Heatmap = Metrics.Heatmap;

  /// Returns a metric for the current canister cycles balance.
  public let cyclesBalanceMetric = Metrics.cyclesBalanceMetric;

  /// Returns a metric for the current canister version.
  public let canisterVersionMetric = Metrics.canisterVersionMetric;

  /// Returns a bundle of all available IC system and RTS metrics.
  public let allSystemMetrics = Metrics.allSystemMetrics;

  /// Returns a bundle of all available Motoko Runtime System (RTS) metrics.
  public let allRtsMetrics = Metrics.allRtsMetrics;

  /// Creates a new `Value` that calls a function to get its current value.
  public let newValue = Metrics.newPullValue;

  /// Bundles multiple `Value` objects into a single `Value`.
  ///
  /// Common labels are prepended to all metrics produced by the bundled values.
  public let bundle = Metrics.bundle;

  /// High-level renderer for metric exposition.
  ///
  /// The `Renderer` manages global labels and a set of `Value` objects (such as
  /// trackers or pull metrics). It is typically used in the `http_request`
  /// method of an actor to produce the Prometheus exposition.
  ///
  /// The `Renderer` is transient; its state (labels and values) should be
  /// re-initialized after a canister upgrade.
  public class Renderer() {
    // Global labels managed by the Renderer
    var labels : Text = "";

    /// Clears all global labels.
    public func clearLabels() { labels := "" };

    /// Adds a global label to the renderer.
    ///
    /// Traps if `key` is an invalid label name.
    public func addLabel(key : Text, value : Text) {
      labels := Label.concat(labels, Label.renderLabel(key, value));
    };

    /// Adds a `canister="id"` label for the given actor.
    ///
    /// Traps if the canister ID cannot be extracted from the actor's principal.
    public func addCanisterLabel(a : actor {}) {
      addLabel(Label.canisterLabel(a));
    };

    // Transient values managed by the Renderer
    // Trackers are added just like any other pull value
    var values = List.empty<(Nat, Metrics.Value)>();
    var nonce : Nat = 0;
    /// Adds a `Value` reference to the renderer.
    ///
    /// Returns a unique identifier that can be used to remove the value later.
    public func addValueRef(v : Metrics.Value) : Nat {
      nonce += 1;
      values := values.pushFront((nonce, v));
      nonce;
    };
    /// Adds a `Value` to the renderer.
    ///
    /// Values can be trackers (`tracker.toValue()`) or custom pull-based metrics
    /// created with `newValue()`.
    public func addValue(v : Metrics.Value) = ignore addValueRef(v);

    /// Removes a `Value` from the renderer by its identifier.
    public func removeValue(id : Nat) {
      values := values.filter(func(iid, _) = iid != id);
    };

    /// Returns all metrics from all registered values, with global labels prepended.
    public func read() : [Metrics.Metric] {
      let arr = values.map(func(v) = v.1.read()).reverse().toArray().flatten();
      arr.map(func(m) = m.prependLabels(labels));
    };

    /// Renders the registered metrics into Prometheus exposition format.
    public func renderExposition() : Text {
      let timeStr = (Prim.time() / 1_000_000).toText();
      read().map(
        func(metric) = metric.render(timeStr)
      ).vals().join("");
    };
  };
};
