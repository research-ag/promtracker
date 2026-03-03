import Array_ "mo:core/Array";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import Prim "mo:prim";

import Label "./Label";

module {
  // The data in type Metric is (name, labels, value)
  public type Metric = (Text, Text, Nat);

  public func prependLabels(self : Metric, newLabels : Text) : Metric {
    let (name, labels, value) = self;
    (name, concat(newLabels, labels), value);
  };
  public func render(self : Metric, time : Text) : Text {
    let (name, labels, value) = self;
    name # "{" # labels # "} " # value.toText() # " " # time # "\n";
  };

  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  /// Each "Value" can deliver one or more metrics.
  /// For example a Gauge delivers sum, count, lastValue, watermarks, etc.
  /// A Value is a set of metrics.
  public type Value = {
    read : () -> [Metric];
  };

  /// A single pull value
  public func newPullValue(name : Text, labels : [Label.Label], getValue : () -> Nat) : Value {
    let labelsText = Label.renderLabels(labels);
    object {
      public func read() : [Metric] {
        [(name, labelsText, getValue())];
      };
    };
  };

  /// Arbitrary Values can be bundled together to form a new "Value"
  /// Bundling can be nested.
  public func newPullValueBundle(commonLabels : [Label.Label], sets : [Value]) : Value {
    let commonLabelsText = Label.renderLabels(commonLabels);
    object {
      public func read() : [Metric] {
        // read metrics from all sets
        let allMetrics = sets.map(func(s) = s.read()).flatten();
        // add common labels to all metrics
        allMetrics.map(func(m) = m.prependLabels(commonLabelsText));
      };
    };
  };

  public let allSystemMetrics : Value = {
    read = func() = [
      ("canister_version", "", Prim.canisterVersion().toNat()),
      ("cycles_balance", "", Prim.cyclesBalance()),
      ("rts_memory_size", "", Prim.rts_memory_size()),
      ("rts_heap_size", "", Prim.rts_heap_size()),
      ("rts_total_allocation", "", Prim.rts_total_allocation()),
      ("rts_reclaimed", "", Prim.rts_reclaimed()),
      ("rts_max_live_size", "", Prim.rts_max_live_size()),
      ("rts_max_stack_size", "", Prim.rts_max_stack_size()),
      ("rts_callback_table_count", "", Prim.rts_callback_table_count()),
      ("rts_callback_table_size", "", Prim.rts_callback_table_size()),
      ("rts_mutator_instructions", "", Prim.rts_mutator_instructions()),
      ("rts_collector_instructions", "", Prim.rts_collector_instructions()),
      ("rts_upgrade_instructions", "", Prim.rts_upgrade_instructions()),
      ("rts_stable_memory_size", "", Prim.rts_stable_memory_size()),
      ("rts_logical_stable_memory_size", "", Prim.rts_logical_stable_memory_size()),
    ];
  };

  public let canisterVersionMetric : Value = {
    read = func() = [("canister_version", "", Prim.canisterVersion().toNat())];
  };

  public let cyclesBalanceMetric : Value = {
    read = func() = [("cycles_balance", "", Prim.cyclesBalance())];
  };

  public let allRtsMetrics : Value = {
    read = func() = [
      ("rts_memory_size", "", Prim.rts_memory_size()),
      ("rts_heap_size", "", Prim.rts_heap_size()),
      ("rts_total_allocation", "", Prim.rts_total_allocation()),
      ("rts_reclaimed", "", Prim.rts_reclaimed()),
      ("rts_max_live_size", "", Prim.rts_max_live_size()),
      ("rts_max_stack_size", "", Prim.rts_max_stack_size()),
      ("rts_callback_table_count", "", Prim.rts_callback_table_count()),
      ("rts_callback_table_size", "", Prim.rts_callback_table_size()),
      ("rts_mutator_instructions", "", Prim.rts_mutator_instructions()),
      ("rts_collector_instructions", "", Prim.rts_collector_instructions()),
      ("rts_upgrade_instructions", "", Prim.rts_upgrade_instructions()),
      ("rts_stable_memory_size", "", Prim.rts_stable_memory_size()),
      ("rts_logical_stable_memory_size", "", Prim.rts_logical_stable_memory_size()),
    ];
  };

  public module Counter {
    public type Counter = {
      name : Text;
      labels : Text;
      var value : Nat;
      id : Nat;
    };

    public func new(name : Text, labels : Text, id : Nat) : Counter = {
      name;
      labels;
      var value = 0;
      id;
    };
    public func add(self : Counter, n : Nat) { self.value += n };
    public func value(self : Counter) : Value = {
      read = func() = [(self.name, self.labels, self.value)];
    };
  };

  public module Gauge {
    // Env
    type Env = {
      var holdDownPeriod : Nat64; // in nanoseconds
    };
    public func env(holdDownSeconds : Nat) : Env = {
      var holdDownPeriod = holdDownSeconds.toNat64() * 1_000_000_000;
    };
    public func setHoldDown(self : Env, seconds : Nat) {
      self.holdDownPeriod := seconds.toNat64() * 1_000_000_000;
    };

    // Watermark
    type Watermark = {
      var activated : Bool; // a watermark is activated after the first update
      var mark : Nat;
      var lastMarkTime : Nat64;
      env : Env;
    };
    func newWatermark(env : Env) : Watermark = {
      var activated = false;
      var mark = 0;
      var lastMarkTime = 0;
      env;
    };
    func updateWatermark(self : Watermark, value : Nat, time : Nat64, isHigher : (Nat, Nat) -> Bool) {
      if (
        self.activated and
        not isHigher(value, self.mark) and
        time <= self.lastMarkTime + self.env.holdDownPeriod
      ) return;
      self.activated := true;
      self.mark := value;
      self.lastMarkTime := time;
    };

    // Gauge
    public type Gauge = {
      prefix : Text;
      labels : Text;
      var lastValue : Nat;
      var count : Nat;
      var sum : Nat;
      high : Watermark;
      low : Watermark;
      id : Nat;
    };
    public func new(prefix : Text, labels : Text, env : Env, id : Nat) : Gauge = {
      prefix;
      labels;
      var lastValue = 0;
      var count = 0;
      var sum = 0;
      high = newWatermark(env);
      low = newWatermark(env);
      id;
    };
    public func value(self : Gauge) : Value = {
      read = func() {
        var metrics = [
          (self.prefix # "_last", self.labels, self.lastValue),
          (self.prefix # "_sum", self.labels, self.sum),
          (self.prefix # "_count", self.labels, self.count),
        ];
        if (self.high.activated) {
          metrics := metrics.concat([(self.prefix # "_high_watermark", self.labels, self.high.mark)]);
        };
        if (self.low.activated) {
          metrics := metrics.concat([(self.prefix # "_low_watermark", self.labels, self.low.mark)]);
        };
        metrics;
      };
    };
    public func update(self : Gauge, value : Nat) {
      self.lastValue := value;
      self.count += 1;
      self.sum += value;
      let now = Prim.time();
      updateWatermark(self.high, value, now, func(new, old) = new > old);
      updateWatermark(self.low, value, now, func(new, old) = new < old);
    };
  };

};
