import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat64_ "mo:core/Nat64";
import Principal "mo:core/Principal";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";
import T "Tracker";

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

  // Constructor and other functions passthrough
  public func new() : Tracker = T.new();
  public func newGauge(self : Tracker, name : Text, labels : Text) : Gauge {
    T.newGauge(self, name, labels);
  };
  public func newCounter(self : Tracker, name : Text, labels : Text) : Counter {
    T.newCounter(self, name, labels);
  };
  public func setHoldDown(self : Tracker, seconds : Nat) {
    T.setHoldDown(self, seconds);
  };

  // Helper function to create canister label from an actor reference
  public func canisterLabel(a : actor {}) : Text {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Prim.trap("");
    return "canister=\"" # name # "\"";
  };

  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  // Renderer class, wrapper around the static Tracker
  public class Renderer(tracker : Tracker) {
    // Global labels managed by the Renderer
    var labels : Text = "";
    public func setLabels(labels_ : Text) {
      labels := labels_;
    };
    public func addLabel(key : Text, value : Text) {
      labels := concat(labels, key # "=\"" # value # "\"");
    };
    public func addCanisterLabel(a : actor {}) {
      let s = Principal.fromActor(a).toText();
      let ?name = s.split(#char '-').next() else Prim.trap("");
      addLabel("canister", name);
    };

    // Transient values managed by the Renderer
    var values = List.empty<Metrics.Value>();
    public func addPullValue(v : Metrics.Value) {
      values := values.pushFront(v);
    };
    public func addPullValues(vs : [Metrics.Value]) {
      for (v in vs.values()) {
        values := values.pushFront(v);
      };
    };

    // Read all values as array
    // PullValues first, then stable values, in the order of addition for both categories
    public func read() : [Metrics.Metric] {
      let arr1 = values.map(func(v) = v.read()).reverse().toArray().flatten();
      let arr2 = tracker.read();
      [arr1, arr2].flatten();
    };

    // Render exposition
    public func renderExposition() : Text {
      let timeStr = (Prim.time() / 1_000_000).toText();
      read().map(
        func(metric) = metric.render(concat(labels, tracker.labels), timeStr)
      ).vals().join("");
    };
  };
};
