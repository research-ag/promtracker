import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import Principal "mo:core/Principal";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";
import Label "Label";

module {
  // Type passthrough
  public type Counter = Metrics.Counter.Counter;
  public type Gauge = Metrics.Gauge.Gauge;

  // Helper functions
  public func canisterLabel(a : actor {}) : Label.Label {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Prim.trap("");
    return ("canister", name);
//    return Label.renderLabel("canister", name);
  };

  // Value variant type
  type Value = {
    #counter : Metrics.Counter.Counter;
    #gauge : Metrics.Gauge.Gauge;
    #tracker : Tracker;
  };
  private func readValue(val : Value) : [Metrics.Metric] {
    switch val {
      case (#counter ctr) { Metrics.Counter.value(ctr).read() };
      case (#gauge g) { Metrics.Gauge.value(g).read() };
      case (#tracker t) { t.read() };
    };
  };

  // Watermark environment
  type Environment = {
    var holdDownPeriod : Nat64; // in nanoseconds
  };
  func nanos(seconds : Nat) : Nat64 = seconds.toNat64() * 1_000_000_000;

  // Static tracker type
  public type Tracker = {
    var labels : Text;
    var values : List.List<Value>;
    env : Environment;
    var nonce : Nat;
    id : Nat;
  };

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
    labels_ : Text,
    initialValues : [Value],
    seconds : Nat,
  ) : Tracker {
    let tracker : Tracker = {
      var labels = labels_;
      var values = List.empty();
      env = { var holdDownPeriod = nanos(seconds) };
      var nonce = 0;
      id = 0;
    };
    addMany(tracker, initialValues);
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
  public func add(self : Tracker, val : Value) {
    self.values := self.values.pushFront(val);
  };
  public func addMany(self : Tracker, vals : [Value]) {
    for (v in vals.values()) {
      self.values := self.values.pushFront(v);
    };
  };
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter {
    let labelStr = Label.renderLabels(labels); 
    let newCounter = Metrics.Counter.new(name, labelStr, self.nonce);
    self.nonce += 1;
    self.add(#counter newCounter);
    newCounter;
  };
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Gauge.Gauge {
    let labelStr = Label.renderLabels(labels);
    let newGauge = Metrics.Gauge.new(prefix, labelStr, self.env, self.nonce);
    self.nonce += 1;
    self.add(#gauge newGauge);
    newGauge;
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
    self.values := self.values.filter(func(v) = switch v {
      case (#counter c) { c.id != value.id };
      case (#gauge g) { g.id != value.id };
      case (#tracker t) { t.id != value.id };
    });
  };

  /// Read all current metrics as a structured array
  public func read(self : Tracker) : [Metrics.Metric] {
    let all = self.values.map(func(v) = readValue(v)).reverse().toArray().flatten();
    all.map(func(m) = m.prependLabels(self.labels));
  };

  public func renderExposition(self : Tracker) : Text {
    let timeStr = (Prim.time() / 1_000_000).toText();
    read(self).map(
      func(metric) = metric.render(timeStr)
    ).vals().join("");
  };

  public func renderFunction(self : Tracker) : () -> Text {
    func() = self.renderExposition();
  };

};
