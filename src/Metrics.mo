import Array_ "mo:core/Array";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import Prim "mo:prim";

module {
  // The data in type Metric is (name, labels, value)
  public type Metric = (Text, Text, Nat);

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
  public func singleton(name : Text, labels : Text, getValue : () -> Nat) : Value = object {
    public func read() : [Metric] { [(name, labels, getValue())] };
  };

  /// Arbitrary Values can be bundled together to form a new "Value"
  /// Bundling can be nested.
  public func bundle(commonLabels : Text, sets : [Value]) : Value = object {
    public func read() : [Metric] {
      // read metrics from all sets
      let allMetrics = sets.map(func(s) = s.read()).flatten();
      // add common labels to all metrics
      allMetrics.map(func(name, labels, value) { (name, concat(commonLabels, labels), value) });
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
    };

    public func new(name : Text, labels : Text) : Counter = {
      name = name;
      labels = labels;
      var value = 0;
    };
    public func add(self : Counter, n : Nat) { self.value += n };
    public func metrics(self : Counter) : Value = {
      read = func() = [(self.name, self.labels, self.value)];
    };
  };

  public module Gauge {
    // Env
    type Env = {
      var holdDownPeriod : Nat64;
    };
    public func env(holdDownSeconds : Nat) : Env = {
      var holdDownPeriod = holdDownSeconds.toNat64() * 1_000_000_000;
    };
    public func setHoldDown(self : Env, seconds : Nat) {
      self.holdDownPeriod := seconds.toNat64() * 1_000_000_000;
    };

    // Watermark
    type Watermark = {
      var activated : Bool;
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
    func updateWM(self : Watermark, value : Nat, time : Nat64, isHigher : (Nat, Nat) -> Bool) {
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
      highWatermark : Watermark;
      lowWatermark : Watermark;
    };
    public func new(prefix : Text, labels : Text, env : Env) : Gauge = {
      prefix = prefix;
      labels = labels;
      var lastValue = 0;
      var count = 0;
      var sum = 0;
      highWatermark = newWatermark(env);
      lowWatermark = newWatermark(env);
    };
    public func metrics(self : Gauge) : Value = {
      read = func() {
        var metrics = [
          (self.prefix # "_last", self.labels, self.lastValue),
          (self.prefix # "_sum", self.labels, self.sum),
          (self.prefix # "_count", self.labels, self.count),
        ];
        if (self.highWatermark.activated) {
          metrics := metrics.concat([(self.prefix # "_high_watermark", self.labels, self.highWatermark.mark)]);
        };
        if (self.lowWatermark.activated) {
          metrics := metrics.concat([(self.prefix # "_low_watermark", self.labels, self.lowWatermark.mark)]);
        };
        metrics;
      };
    };
    public func update(self : Gauge, value : Nat) {
      self.lastValue := value;
      self.count += 1;
      self.sum += value;
      updateWM(self.highWatermark, value, Prim.time(), func(new, old) = new > old);
      updateWM(self.lowWatermark, value, Prim.time(), func(new, old) = new < old);
    };
  };

};
