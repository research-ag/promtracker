import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat64_ "mo:core/Nat64";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";
import T "Tracker";
import Label "Label";

/// Module contains the Renderer and passes through the Tracker
module {
  // Type passthrough
  public type Tracker = T.Tracker;
  public type Counter = Metrics.Counter.Counter;
  public type Gauge = Metrics.Gauge.Gauge;
  public type Heatmap = Metrics.Heatmap.Heatmap;

  // Module passthrough
  public let Tracker = T;
  public let Counter = Metrics.Counter;
  public let Gauge = Metrics.Gauge;
  public let Heatmap = Metrics.Heatmap;

  // Pre-defined pull values passthrough
  public let cyclesBalanceMetric = Metrics.cyclesBalanceMetric;
  public let canisterVersionMetric = Metrics.canisterVersionMetric;
  public let allSystemMetrics = Metrics.allSystemMetrics;
  public let allRtsMetrics = Metrics.allRtsMetrics;
  public let newValue = Metrics.newPullValue;

  //public let bundle : (self : [Metrics.Value], labels : [Label.Label]) -> Metrics.Value = Metrics.bundle;
  public let bundle = Metrics.bundle;

  /// Renderer class, wrapper around the static Tracker
  ///
  /// The Renderer is defined in the top-level actor code and exists only once.
  /// The Renderer is transient, i.e. all labels and values have to be re-added after every upgrade,
  /// in the top-level actor code.
  /// However, the Renderer can reference a static, stable Tracker as one of its values.
  public class Renderer() {
    // Global labels managed by the Renderer
    var labels : Text = "";

    /// This function should not be needed because labels are cleared on upgrade.
    /// But just in case they ever need to be cleared outside upgrades we provide this function.
    public func clearLabels() { labels := "" };

    /// Add a label
    public func addLabel(key : Text, value : Text) {
      labels := Label.concat(labels, Label.renderLabel(key, value));
    };

    /// Add the canister="id" label with short form canister id
    public func addCanisterLabel(a : actor {}) {
      addLabel(Label.canisterLabel(a));
    };

    // Transient values managed by the Renderer
    // Trackers are added just like any other pull value
    var values = List.empty<(Nat, Metrics.Value)>();
    var nonce : Nat = 0;
    public func addValueRef(v : Metrics.Value) : Nat {
      nonce += 1;
      values := values.pushFront((nonce, v));
      nonce;
    };
    public func addValue(v : Metrics.Value) = ignore addValueRef(v);
    public func removeValue(id : Nat) {
      values := values.filter(func(iid, _) = iid != id);
    };

    // Read all values as array
    public func read() : [Metrics.Metric] {
      let arr = values.map(func(v) = v.1.read()).reverse().toArray().flatten();
      arr.map(func(m) = m.prependLabels(labels));
    };

    // Render exposition
    public func renderExposition() : Text {
      let timeStr = (Prim.time() / 1_000_000).toText();
      read().map(
        func(metric) = metric.render(timeStr)
      ).vals().join("");
    };
  };
};
