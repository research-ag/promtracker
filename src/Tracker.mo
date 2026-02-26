import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import Principal "mo:core/Principal";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";

module {
  // Type passthrough
  public type Counter = Metrics.Counter.Counter;
  public type Gauge = Metrics.Gauge.Gauge;

  // Helper functions
  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };
  public func canisterLabel(a : actor {}) : Text {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Prim.trap("");
    return "canister=\"" # name # "\"";
  };

  // Value variant type
  type Value = {
    #counter : Metrics.Counter.Counter;
    #gauge : Metrics.Gauge.Gauge;
  };
  private func readValue(val : Value) : [Metrics.Metric] {
    switch val {
      case (#counter ctr) { Metrics.Counter.value(ctr).read() };
      case (#gauge g) { Metrics.Gauge.value(g).read() };
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
  };

  public func new() : Tracker {
    let tracker : Tracker = {
      var labels = "";
      var values = List.empty();
      env = { var holdDownPeriod = nanos(302) };
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
    };
    addMany(tracker, initialValues);
    tracker;
  };

  public func setHoldDown(self : Tracker, seconds : Nat) {
    self.env.holdDownPeriod := nanos(seconds);
  };
  public func setLabels(self : Tracker, labels : Text) {
    self.labels := labels;
  };
  public func addLabel(self : Tracker, key : Text, value : Text) {
    self.labels := concat(self.labels, key # "=\"" # value # "\"");
  };
  public func addCanisterLabel(self : Tracker, a : actor {}) {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Prim.trap("Should not happen: actor principal cannot be parsed");
    addLabel(self, "canister", name);
  };
  public func add(self : Tracker, val : Value) {
    self.values := self.values.pushFront(val);
  };
  public func addMany(self : Tracker, vals : [Value]) {
    for (v in vals.values()) {
      self.values := self.values.pushFront(v);
    };
  };
  public func newCounter(self : Tracker, name : Text, labels : Text) : Metrics.Counter.Counter {
    let newCounter = Metrics.Counter.new(name, labels);
    self.add(#counter newCounter);
    newCounter;
  };
  public func newGauge(self : Tracker, prefix : Text, labels : Text) : Metrics.Gauge.Gauge {
    let newGauge = Metrics.Gauge.new(prefix, labels, self.env);
    self.add(#gauge newGauge);
    newGauge;
  };

  /// Read all current metrics as a structured array
  public func read(self : Tracker) : [Metrics.Metric] {
    self.values.map(func(v) = readValue(v)).reverse().toArray().flatten();
  };

  public func renderExposition(self : Tracker) : Text {
    let timeStr = (Prim.time() / 1_000_000).toText();
    read(self).map(
      func(metric) = metric.render(self.labels, timeStr)
    ).vals().join("");
  };

  public func renderFunction(self : Tracker) : () -> Text {
    func() = self.renderExposition();
  };

};
