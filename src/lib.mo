/// Main entry point for the Prometheus metric tracking library.
///
/// This module provides the `Renderer` class for top-level metric exposition
/// and re-exports the `Tracker` and metric types for convenience.
///
/// ```motoko name=import
/// import PromTracker "mo:promtracker/Tracker";
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
  /// Passthrough for `Tracker.Tracker`.
  public type Tracker = T.Tracker;

  /// Passthrough for `Metrics.Counter.Counter`.
  public type Counter = Metrics.Counter.Counter;

  /// Passthrough for `Metrics.Gauge.Gauge`.
  public type Gauge = Metrics.Gauge.Gauge;

  /// Passthrough for `Metrics.Heatmap.Heatmap`.
  public type Heatmap = Metrics.Heatmap.Heatmap;

  /// Passthrough for the `Tracker` module.
  public let Tracker = T;

  /// Passthrough for the `Counter` module.
  public let Counter = Metrics.Counter;

  /// Passthrough for the `Gauge` module.
  public let Gauge = Metrics.Gauge;

  /// Passthrough for the `Heatmap` module.
  public let Heatmap = Metrics.Heatmap;

  /// Passthrough for `Metrics.cyclesBalanceMetric`.
  public let cyclesBalanceMetric = Metrics.cyclesBalanceMetric;

  /// Passthrough for `Metrics.canisterVersionMetric`.
  public let canisterVersionMetric = Metrics.canisterVersionMetric;

  /// Passthrough for `Metrics.allSystemMetrics`.
  public let allSystemMetrics = Metrics.allSystemMetrics;

  /// Passthrough for `Metrics.allRtsMetrics`.
  public let allRtsMetrics = Metrics.allRtsMetrics;

  /// Passthrough for `Metrics.newPullValue`.
  public let newValue = Metrics.newPullValue;

  /// Passthrough for `Metrics.bundle`.
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
