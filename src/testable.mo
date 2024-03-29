import Array "mo:base/Array";
import AssocList "mo:base/AssocList";
import Cycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import StableMemory "mo:base/ExperimentalStableMemory";
import Text "mo:base/Text";
import Prim "mo:prim";
import Vector "mo:vector/Class";

module {
  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  type StableDataItem = {
    #counter : Nat;
    #gauge : (Nat, Nat, Nat, [Nat], [Nat]);
  };
  public type StableData = AssocList.AssocList<Text, StableDataItem>;

  // The data in type Metric is (name, labels, value)
  type Metric = (Text, Text, Nat);

  // The two components of the watermark environment are:
  // - the interval after which the watermarks are reset in seconds as Nat
  // - the function that returns the current time in nanoseconds as Nat64
  type WatermarkEnvironment = (Nat64, () -> Nat64);

  /// An access interface for pull value
  public type PullValueInterface = {
    value : () -> Nat;
    remove : () -> ();
  };
  /// An access interface for counter value
  public type CounterInterface = {
    value : () -> Nat;
    set : (x : Nat) -> ();
    add : (x : Nat) -> ();
    sub : (x : Nat) -> ();
    remove : () -> ();
  };
  /// An access interface for gauge value
  public type GaugeInterface = {
    value : () -> Nat;
    sum : () -> Nat;
    count : () -> Nat;
    update : (x : Nat) -> ();
    remove : () -> ();
  };

  public class PromTracker(staticGlobalLabels : Text, watermarkResetIntervalSeconds : Nat, now : () -> Nat64) {
    let env : WatermarkEnvironment = (
      Nat64.fromNat(watermarkResetIntervalSeconds) * 1_000_000_000,
      now,
    );
    type IValue = {
      prefix : Text;
      labels : Text;
      dump : () -> [Metric];
      share : () -> ?StableDataItem;
      unshare : (StableDataItem) -> ();
    };

    let values = Vector.Vector<?IValue>();

    /// Register a PullValue in the tracker.
    /// A PullValue is stateless.
    /// It is calculated dynamically by calling the `pull` function that is provided as a constructor argument.
    ///
    /// Example:
    /// ```motoko
    /// let storageSize = tracker.addPullValue("storage_size", func() = storage.size());
    /// ```
    public func addPullValue(prefix : Text, labels : Text, pull : () -> Nat) : PullValueInterface {
      // create and register the value
      let id = values.size();
      let value = PullValue(prefix, labels, pull);
      values.add(?value);
      // return the interface
      {
        value = pull;
        remove = func() = removeValue(id);
      };
    };

    /// Register a CounterValue in the tracker.
    /// A CounterValue is stateful. It is either set to a concrete value or incremented by a delta.
    ///
    /// A CounterValue can be declated stable by setting the second argument to `true`.
    /// In this case it will preserved across canister upgrades.
    ///
    /// Example:
    /// ```motoko
    /// let requestsAmount = tracker.addCounter("requests_amount", true);
    /// ....
    /// requestsAmount.add(3);
    /// requestsAmount.add(1);
    /// ```
    public func addCounter(prefix : Text, labels : Text, isStable : Bool) : CounterInterface {
      // create and register the value
      let id = values.size();
      let value = CounterValue(prefix, labels, isStable);
      values.add(?value);
      // return the interface
      {
        value = func() = value.value;
        set = value.set;
        add = value.add;
        sub = value.sub;
        remove = func() = removeValue(id);
      };
    };

    /// Register a GaugeValue in the tracker.
    /// A GaugeValue is stateful. It's value can be updated by overwriting it's previous value.
    /// A GaugeValue keeps some information about it's history such as high and low watermarks
    /// and histogram buckets counters that can be used to create heatmaps.
    ///
    /// If the second argument is an empty list then no histogram buckets are tracked.
    /// ```motoko
    /// let requestDuration = tracker.addGauge("request_duration", ?[50, 110]);
    /// requestDuration.update(123);
    /// requestDuration.update(101);
    /// // now it will output stats:
    /// // request_duration_sum: 224
    /// // request_duration_count: 2
    /// // request_duration_high_watermark: 123
    /// // request_duration_low_watermark: 101
    /// // request_duration_low_watermark: 101
    /// // request_duration_bucket{le="50"}: 0
    /// // request_duration_bucket{le="110"}: 1
    /// // request_duration_bucket{le="+Inf"} 2
    /// ```
    public func addGauge(prefix : Text, labels : Text, watermarks : { #none; #low; #high; #both }, bucketLimits : [Nat], isStable : Bool) : GaugeInterface {
      // check order of buckets
      let l = bucketLimits;
      var i = 1;
      while (i < l.size()) {
        if (l[i - 1] >= l[i]) Prim.trap("Buckets have to be ordered and non-empty");
        i += 1;
      };
      // create and register the value
      let gaugeId = values.size();
      let (lowWM, highWM) = switch (watermarks) {
        case (#none) (false, false);
        case (#low) (true, false);
        case (#high) (false, true);
        case (#both) (true, true);
      };
      let gaugeValue = GaugeValue(prefix, labels, lowWM, highWM, bucketLimits, env, isStable);
      values.add(?gaugeValue);
      // return the interface
      {
        value = func() = gaugeValue.lastValue;
        sum = func() = gaugeValue.sum;
        count = func() = gaugeValue.count;
        update = gaugeValue.update;
        remove = func() = removeValue(gaugeId);
      };
    };

    /// Add system metrics, such as cycle balance, memory size, heap size etc.
    public func addSystemValues() {
      ignore addPullValue("cycles_balance", "", func() = Cycles.balance());
      ignore addPullValue("rts_memory_size", "", func() = Prim.rts_memory_size());
      ignore addPullValue("rts_heap_size", "", func() = Prim.rts_heap_size());
      ignore addPullValue("rts_total_allocation", "", func() = Prim.rts_total_allocation());
      ignore addPullValue("rts_reclaimed", "", func() = Prim.rts_reclaimed());
      ignore addPullValue("rts_max_live_size", "", func() = Prim.rts_max_live_size());
      ignore addPullValue("rts_max_stack_size", "", func() = Prim.rts_max_stack_size());
      ignore addPullValue("rts_callback_table_count", "", func() = Prim.rts_callback_table_count());
      ignore addPullValue("rts_callback_table_size", "", func() = Prim.rts_callback_table_size());
      ignore addPullValue("rts_mutator_instructions", "", func() = Prim.rts_mutator_instructions());
      ignore addPullValue("rts_collector_instructions", "", func() = Prim.rts_collector_instructions());
      ignore addPullValue("stablememory_size", "", func() = Nat64.toNat(StableMemory.size()));
    };

    func removeValue(id : Nat) : () = values.put(id, null);

    /// Dump all current metrics to an array
    public func dump() : [Metric] {
      let result = Vector.Vector<Metric>();
      for (v in values.vals()) {
        switch (v) {
          case (?value) Vector.addFromIter(result, Iter.fromArray(value.dump()));
          case (null) {};
        };
      };
      Vector.toArray(result);
    };

    func renderMetric(m : Metric, globalLabels : Text, time : Text) : Text {
      let (metricName, metricLabels, natValue) = m;
      metricName # "{" # concat(globalLabels, metricLabels) # "} "
      # Nat.toText(natValue) # " " # time # "\n";
    };

    /// Render all current metrics to prometheus exposition format
    public func renderExposition(dynamicGlobalLabels : Text) : Text {
      let timeStr = Nat64.toText(now() / 1_000_000);
      let globalLabels = concat(staticGlobalLabels, dynamicGlobalLabels);
      let lines = Array.map<Metric, Text>(
        dump(),
        func(m) = renderMetric(m, globalLabels, timeStr),
      );
      Text.join("", lines.vals());
    };

    private func stablePrefix(v : IValue) : Text = switch (v.labels.size()) {
      case (0) v.prefix;
      case (_) v.prefix # "{}" # v.labels;
    };

    /// Dump all values, marked as stable, to stable data structure
    public func share() : StableData {
      var res : StableData = null;
      for (value in values.vals()) {
        switch (value) {
          case (?v) switch (v.share()) {
            case (?data) {
              res := AssocList.replace(res, stablePrefix(v), Text.equal, ?data).0;
            };
            case (_) {};
          };
          case (null) {};
        };
      };
      res;
    };

    /// Restore all values from stable data
    public func unshare(data : StableData) : () {
      for (value in values.vals()) {
        switch (value) {
          case (?v) switch (AssocList.find(data, stablePrefix(v), Text.equal)) {
            case (?data) v.unshare(data);
            case (_) {};
          };
          case (_) {};
        };
      };
    };
  };

  class PullValue(prefix_ : Text, labels_ : Text, pull : () -> Nat) {
    public let prefix = prefix_;
    public let labels = labels_;

    public func dump() : [Metric] = [(prefix, labels, pull())];

    public func share() : ?StableDataItem = null;
    public func unshare(data : StableDataItem) = ();
  };

  class CounterValue(prefix_ : Text, labels_ : Text, isStable : Bool) {
    public let prefix = prefix_;
    public let labels = labels_;

    public var value = 0;

    public func add(n : Nat) { value += n };
    public func sub(n : Nat) { value -= n };
    public func set(n : Nat) { value := n };

    public func dump() : [Metric] = [(prefix, labels, value)];

    public func share() : ?StableDataItem {
      if (not isStable) return null;
      ? #counter(value);
    };
    public func unshare(data : StableDataItem) = switch (data, isStable) {
      case (#counter x, true) value := x;
      case (_) {};
    };
  };

  class WatermarkTracker<T>(initialMark : T, isHigher : (new : T, old : T) -> Bool, resetInterval : Nat64) {
    var lastMarkTime : Nat64 = 0;
    public var mark : T = initialMark;
    public func update(value : T, time : Nat64) {
      if (isHigher(value, mark) or time > lastMarkTime + resetInterval) {
        mark := value;
        lastMarkTime := time;
      };
    };
  };
  class GaugeValue(prefix_ : Text, labels_ : Text, enableLowWM : Bool, enableHighWM : Bool, limits_ : [Nat], env : WatermarkEnvironment, isStable : Bool) {
    public let prefix = prefix_;
    public let labels = labels_;

    let (resetInterval, now) = env;

    public var count : Nat = 0;
    public var sum : Nat = 0;
    var limits = limits_;
    public var counters : [var Nat] = Array.init<Nat>(limits.size(), 0);
    public var highWatermark : WatermarkTracker<Nat> = WatermarkTracker<Nat>(0, func(new, old) = new > old, resetInterval);
    public var lowWatermark : WatermarkTracker<Nat> = WatermarkTracker<Nat>(0, func(new, old) = new < old, resetInterval);
    public var lastValue : Nat = 0;

    public func update(current : Nat) {
      lastValue := current;
      // main counters
      count += 1;
      sum += current;
      // watermarks
      if (enableLowWM or enableHighWM) {
        let t = now();
        if (enableLowWM) {
          lowWatermark.update(current, t);
        };
        if (enableHighWM) {
          highWatermark.update(current, t);
        };
      };
      // bucket counters
      var n = limits.size();
      while (n > 0) {
        n -= 1;
        if (current > limits[n]) return;
        counters[n] += 1;
      };
    };

    func metric(suffix : Text, labels : Text, value : Nat) : Metric {
      (prefix # "_" # suffix, labels, value);
    };

    public func dump() : [Metric] {
      let all = Vector.fromArray<Metric>([
        metric("last", labels, lastValue),
        metric("sum", labels, sum),
        metric("count", labels, count),
      ]);
      if (enableHighWM) {
        all.add(metric("high_watermark", labels, highWatermark.mark));
      };
      if (enableLowWM) {
        all.add(metric("low_watermark", labels, lowWatermark.mark));
      };
      for (i in counters.keys()) {
        all.add(metric("bucket", concat(labels, "le=\"" # Nat.toText(limits[i]) # "\""), counters[i]));
      };
      if (counters.size() > 0) {
        all.add(metric("bucket", concat(labels, "le=\"+Inf\""), count));
      };
      Vector.toArray(all);
    };

    public func share() : ?StableDataItem {
      if (not isStable) return null;
      ? #gauge(lastValue, count, sum, limits, Array.freeze(counters));
    };
    public func unshare(data : StableDataItem) = switch (data, isStable) {
      case (#gauge(v, c, s, bl, bv), true) {
        lastValue := v;
        count := c;
        sum := s;
        limits := bl;
        counters := Array.thaw(bv);
      };
      case (_) {};
    };
  };
};
