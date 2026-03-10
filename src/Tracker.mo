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
  // Type passthrough
  public type Counter = Metrics.Counter.Counter;
  public type Gauge = Metrics.Gauge.Gauge;
  public type Heatmap = Metrics.Heatmap.Heatmap;
  public type Value = Metrics.Value;
  public type Tracker = Types.Tracker;

  // Helper functions
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

  // Static tracker type
  public func new() : Tracker {
    let tracker : Tracker = {
      var labels = "";
      var values = List.empty();
      env = { var holdDownPeriod = nanos(302) };
      var nonce = 0;
      id = 0;
    };
    tracker;
  };
  public func newWith(
    labels_ : [(Text, Text)],
    seconds : Nat,
  ) : Tracker {
    let tracker : Tracker = {
      var labels = Label.renderLabels(labels_);
      var values = List.empty();
      env = { var holdDownPeriod = nanos(seconds) };
      var nonce = 0;
      id = 0;
    };
    tracker;
  };

  public func setHoldDown(self : Tracker, seconds : Nat) {
    self.env.holdDownPeriod := nanos(seconds);
  };
  public func setLabels(self : Tracker, labels : [Label.Label]) {
    self.labels := Label.renderLabels(labels);
  };
  public func addLabel(self : Tracker, key : Text, value : Text) {
    self.labels := Label.concat(self.labels, Label.renderLabel(key, value));
  };
  public func addCanisterLabel(self : Tracker, a : actor {}) {
    let (k, v) = Label.canisterLabel(a);
    addLabel(self, k, v);
  };
  private func add(self : Tracker, val : Types.TValue) {
    self.values := self.values.pushFront(val);
  };
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter {
    let labelStr = Label.renderLabels(labels);
    let newCounter = Metrics.Counter.new(name, labelStr, self.nonce);
    self.nonce += 1;
    self.add(#counter newCounter);
    newCounter;
  };
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge {
    let labelStr = Label.renderLabels(labels);
    let newGauge = Metrics.Gauge.new(prefix, labelStr, self.env, limits, self.nonce);
    self.nonce += 1;
    self.add(#gauge newGauge);
    newGauge;
  };
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap {
    let labelStr = Label.renderLabels(labels);
    let newHeatmap = Metrics.Heatmap.new(prefix, labelStr, self.nonce);
    self.nonce += 1;
    self.add(#heatmap newHeatmap);
    newHeatmap;
  };
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker {
    let labelStr = Label.renderLabels(labels);
    let newTracker : Tracker = {
      var labels = labelStr;
      var values = List.empty();
      env = self.env;
      var nonce = 0;
      id = self.nonce;
    };
    self.nonce += 1;
    self.add(#tracker newTracker);
    newTracker;
  };
  public func removeValue(self : Tracker, value : { id : Nat }) {
    self.values := self.values.filter(
      func(v) = switch v {
        case (#counter c) { c.id != value.id };
        case (#gauge g) { g.id != value.id };
        case (#heatmap h) { h.id != value.id };
        case (#tracker t) { t.id != value.id };
      }
    );
  };

  /// Read all current metrics as a structured array
  public func read(self : Tracker) : [Metrics.Metric] {
    let all = self.values.map(func(v) = readValue(v)).reverse().toArray().flatten();
    all.map(func(m) = m.prependLabels(self.labels));
  };

  /// Convert to "pull value" for addition to Renderer
  public func toValue(self : Tracker) : Metrics.Value = {
    read = func() = self.read();
  };

  public func renderExposition(self : Tracker) : Text {
    let timeStr = (Prim.time() / 1_000_000).toText();
    read(self).map(
      func(m) = m.render(timeStr)
    ).vals().join("");
  };

  public func renderFunction(self : Tracker) : () -> Text {
    func() = self.renderExposition();
  };

};
