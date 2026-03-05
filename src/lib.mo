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

  // Module passthrough
  public let Counter = Metrics.Counter;
  public let Gauge = Metrics.Gauge;

  // Pre-defined pull values passthrough
  public let cyclesBalanceMetric = Metrics.cyclesBalanceMetric;
  public let canisterVersionMetric = Metrics.canisterVersionMetric;
  public let allSystemMetrics = Metrics.allSystemMetrics;
  public let allRtsMetrics = Metrics.allRtsMetrics;
  public let bundle = Metrics.bundle;
  public let newPullValue = Metrics.newPullValue;

  // Constructor and other functions passthrough
  public func new() : Tracker = T.new();
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker {
    T.newTracker(self, labels);
  };

  public func newGauge(self : Tracker, name : Text, labels : [Label.Label], limits : [Nat]) : Gauge {
    T.newGauge(self, name, labels, limits);
  };
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Counter {
    T.newCounter(self, name, labels);
  };

  public func setHoldDown(self : Tracker, seconds : Nat) {
    T.setHoldDown(self, seconds);
  };
  public func removeValue(self : Tracker, val : { id : Nat }) {
    T.removeValue(self, val);
  };

  /// Renderer class, wrapper around the static Tracker
  ///
  /// The Renderer is defined in the top-level actor code and exists only once.
  /// The Renderer references the static, stable Tracker but is transient itself.
  /// Labels and pull values have to be (re-)added to the Renderer in the top-level actor code.
  public class Renderer(tracker : Tracker) {
    // Global labels managed by the Renderer
    var labels : Text = "";

    var nonce : Nat = 0;

    /// This function should not be needed because are cleared on upgrade.
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
    var values = List.empty<(Nat, Metrics.Value)>();
    public func addPullValue(v : Metrics.Value) : Nat {
      nonce += 1;
      values := values.pushFront((nonce, v));
      nonce;
    };
    public func removePullValue(id : Nat) {
      values := values.filter(func(iid, _) = iid != id);
    };

    // Read all values as array
    // PullValues first, then stable values, in the order of addition for both categories
    public func read() : [Metrics.Metric] {
      let arr1 = values.map(func(v) = v.1.read()).reverse().toArray().flatten();
      let arr2 = tracker.read();
      [arr1, arr2].flatten().map(func(m) = m.prependLabels(labels));
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
