/// Core metrics logic for Counters, Gauges, and Heatmaps.
///
/// ```motoko name=import
/// import Metrics "mo:promtracker/Metrics";
/// ```

import Array_ "mo:core/Array";
import List_ "mo:core/pure/List";
import Int_ "mo:core/Int";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import VarArray_ "mo:core/VarArray";
import Prim "mo:prim";

import Label "./Label";
import Types "internal/Types";

module {
  /// The data in type Metric is (name, labels, value)
  public type Metric = Types.Metric;

  /// Prepend labels to an existing metric.
  public func prependLabels(self : Metric, newLabels : Text) : Metric {
    let (name, labels, value) = self;
    (name, concat(newLabels, labels), value);
  };

  /// Render a metric in Prometheus exposition format.
  public func render(self : Metric, time : Text) : Text {
    let (name, labels, value) = self;
    name # "{" # labels # "} " # value.toText() # " " # time # "\n";
  };

  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  type IntMetric = (Text, Text, Int);
  func mapIntMetric((p, l, v) : IntMetric) : [Metric] {
    if (v >= 0) {
      [(p, l, Int_.abs(v))];
    } else {
      [
        (p, l, Int_.abs(v)),
        (p # "_negative", l, 1),
      ];
    };
  };

  /// A `Value` is a set of metrics that can be read.
  public type Value = {
    read : () -> [Metric];
  };

  /// Create a new pull-based metric value.
  public func newPullValue(name : Text, labels : [Label.Label], getValue : () -> Nat) : Value {
    let labelsText = Label.renderLabels(labels);
    object {
      public func read() : [Metric] {
        [(name, labelsText, getValue())];
      };
    };
  };

  /// Bundle multiple `Value`s together into a single `Value` with common labels.
  public func bundle(self : [Value], commonLabels : [Label.Label]) : Value {
    let commonLabelsText = Label.renderLabels(commonLabels);
    object {
      public func read() : [Metric] {
        // read metrics from all values
        let allMetrics = self.map(func(s) = s.read()).flatten();
        // add common labels to all metrics
        allMetrics.map(func(m) = m.prependLabels(commonLabelsText));
      };
    };
  };

  /// Bundle containing all system and RTS metrics.
  public let allSystemMetrics : Value = {
    read = func() = [
      ("cycles_balance", "", Prim.cyclesBalance()),
      ("canister_version", "", Prim.canisterVersion().toNat()),
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

  /// Metric for canister version.
  public let canisterVersionMetric : Value = {
    read = func() = [("canister_version", "", Prim.canisterVersion().toNat())];
  };

  /// Metric for cycles balance.
  public let cyclesBalanceMetric : Value = {
    read = func() = [("cycles_balance", "", Prim.cyclesBalance())];
  };

  /// Bundle containing all RTS metrics.
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

  /// Counter metrics.
  public module Counter {
    /// Counter type passthrough.
    public type Counter = Types.Counter;

    /// Create a new counter. Internal use only, prefer `Tracker.newCounter`.
    public func new(parent : Types.Tracker, name : Text, labels : Text, id : Nat) : Counter = {
      parent;
      name;
      labels;
      var value = 0;
      id;
    };

    /// Increment the counter by `n`.
    public func add(self : Counter, n : Nat) { self.value += n };

    /// Decrement the counter by `n`.
    ///
    /// Traps on underflow.
    public func sub(self : Counter, n : Nat) { self.value -= n };

    /// Set the counter to `n`.
    public func set(self : Counter, n : Nat) { self.value := n };

    /// Returns the `Value` interface for this counter.
    public func value(self : Counter) : Value = {
      read = func() = mapIntMetric((self.name, self.labels, self.value));
    };

    /// Unregister this counter from its parent tracker.
    public func unregister(self : Counter) {
      self.parent.values := self.parent.values.filter(
        func(v) = switch v {
          case (#counter c) { c.id != self.id };
          case (_) true;
        }
      );
    };
  };

  /// Gauge metrics with optional watermarks and buckets.
  public module Gauge {
    // Env
    type Env = Types.Environment;
    /// Create a new environment for gauge watermarks.
    public func env(holdDownSeconds : Nat) : Env = {
      var holdDownPeriod = holdDownSeconds.toNat64() * 1_000_000_000;
    };

    /// Set the hold-down period for the environment in seconds.
    public func setHoldDown(self : Env, seconds : Nat) {
      self.holdDownPeriod := seconds.toNat64() * 1_000_000_000;
    };

    // Watermark
    type Watermark = Types.Watermark;
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

    /// Gauge type passthrough.
    public type Gauge = Types.Gauge;

    /// Create a new gauge. Internal use only, prefer `Tracker.newGauge`.
    ///
    /// `limits` defines bucket boundaries for a histogram-like view.
    /// Traps if `limits` are not strictly increasing.
    public func new(parent : Types.Tracker, prefix : Text, labels : Text, env : Env, limits : [Nat], id : Nat) : Gauge {
      for (i in Nat_.range(1, limits.size())) {
        if (limits[i] <= limits[i - 1]) {
          Prim.trap("Gauge limits must be strictly increasing and unique");
        };
      };
      {
        parent;
        prefix;
        labels;
        var lastValue = 0;
        var count = 0;
        var sum = 0;
        high = newWatermark(env);
        low = newWatermark(env);
        limits = limits;
        counters = VarArray_.repeat(0, limits.size());
        id;
      };
    };

    /// Returns the `Value` interface for this gauge.
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
        if (self.limits.size() > 0) {
          for (i in self.limits.keys()) {
            let leLabel = Label.concat(self.labels, Label.renderLabel("le", self.limits[i].toText()));
            metrics := metrics.concat([(self.prefix # "_bucket", leLabel, self.counters[i])]);
          };
          let infLabel = Label.concat(self.labels, Label.renderLabel("le", "+Inf"));
          metrics := metrics.concat([(self.prefix # "_bucket", infLabel, self.count)]);
        };
        metrics;
      };
    };

    /// Update the gauge with a new value.
    public func update(self : Gauge, value : Nat) {
      self.lastValue := value;
      self.count += 1;
      self.sum += value;
      let now = Prim.time();
      updateWatermark(self.high, value, now, func(new, old) = new > old);
      updateWatermark(self.low, value, now, func(new, old) = new < old);
      var n = self.limits.size();
      while (n > 0) {
        n -= 1;
        if (value > self.limits[n]) { return };
        self.counters[n] += 1;
      };
    };

    /// Unregister this gauge from its parent tracker.
    public func unregister(self : Gauge) {
      self.parent.values := self.parent.values.filter(
        func(v) = switch v {
          case (#gauge g) { g.id != self.id };
          case (_) true;
        }
      );
    };
  };

  /// Heatmap metrics with automatic exponential buckets.
  public module Heatmap {
    /// Heatmap type passthrough.
    public type Heatmap = Types.Heatmap;

    func getBucketIndex(entry : Nat) : Nat {
      if (entry == 0) return 0;
      let bits = Nat64_.bitcountLeadingZero(Nat64_.fromNat(entry - 1));
      65 - bits.toNat();
    };

    func getLimitText(bucket : Nat) : Text {
      if (bucket == 0) return "0";
      let v : Nat64 = 1 << Nat64_.fromNat(bucket - 1);
      v.toText();
    };

    func allocateBucketFor(self : Heatmap, entry : Nat) : Nat {
      let bucket = getBucketIndex(entry);
      if (self.buckets.size() < bucket + 1) {
        let nb = VarArray_.tabulate<Int>(
          bucket + 1,
          func(i) { if (i < self.buckets.size()) self.buckets[i] else 0 },
        );
        self.buckets := nb;
      };
      bucket;
    };

    /// Create a new heatmap. Internal use only, prefer `Tracker.newHeatmap`.
    public func new(parent : Types.Tracker, prefix : Text, labels : Text, id : Nat) : Heatmap = {
      parent;
      prefix;
      labels;
      var count = 0;
      var sum = 0;
      var buckets = VarArray_.repeat<Int>(0, 0);
      id;
    };

    /// Add an entry to the heatmap.
    public func add(self : Heatmap, entry : Nat) {
      self.count += 1;
      self.sum += entry;
      let b = allocateBucketFor(self, entry);
      self.buckets[b] += 1;
    };

    /// Remove an entry from the heatmap.
    ///
    /// Traps if `count` or `sum` underflow.
    public func remove(self : Heatmap, entry : Nat) {
      self.count -= 1;
      self.sum -= entry;
      let b = allocateBucketFor(self, entry);
      self.buckets[b] -= 1;
    };

    /// Update an entry in the heatmap.
    ///
    /// Traps if `sum` underflows.
    public func update(self : Heatmap, oldEntryValue : Nat, newEntryValue : Nat) {
      self.sum += newEntryValue;
      self.sum -= oldEntryValue;
      let oldB = allocateBucketFor(self, oldEntryValue);
      let newB = allocateBucketFor(self, newEntryValue);
      if (oldB == newB) return;
      self.buckets[oldB] -= 1;
      self.buckets[newB] += 1;
    };

    /// Returns the `Value` interface for this heatmap.
    public func value(self : Heatmap) : Value = {
      read = func() {
        var aggregated : Int = 0;
        let metrics = Array_.tabulate<IntMetric>(
          self.buckets.size() + 2,
          func(i) {
            if (i < self.buckets.size()) {
              aggregated += self.buckets[i];
              (self.prefix # "_bucket", Label.concat(self.labels, Label.renderLabel("le", getLimitText(i))), aggregated);
            } else if (i == self.buckets.size()) {
              (self.prefix # "_count", self.labels, self.count);
            } else {
              (self.prefix # "_sum", self.labels, self.sum);
            };
          },
        );
        metrics.map(func(s) = mapIntMetric(s)).flatten();
      };
    };

    /// Unregister this heatmap from its parent tracker.
    public func unregister(self : Heatmap) {
      self.parent.values := self.parent.values.filter(
        func(v) = switch v {
          case (#heatmap h) { h.id != self.id };
          case (_) true;
        }
      );
    };
  };

};
