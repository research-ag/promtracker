import Array "mo:core/Array";
import Cycles "mo:core/Cycles";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Text "mo:core/Text";
import List "mo:core/List";
import VarArray "mo:core/VarArray";
import Types "mo:core/Types";
import PureList "mo:core/pure/List";
import Prim "mo:prim";

module {
  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  type StableDataItem = {
    #counter : Nat;
    #gauge : (Nat, Nat, Nat, [Nat], [Nat]);
    #heatmap : (Nat, Nat, [Nat]);
  };

  public type StableData = Types.Pure.List<(Text, StableDataItem)>;

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

  /// An access interface for heatmap value
  public type HeatmapInterface = {
    sum : () -> Nat;
    count : () -> Nat;
    addEntry : (Nat) -> ();
    removeEntry : (Nat) -> ();
    updateEntry : (oldValue : Nat, newValue : Nat) -> ();
    remove : () -> ();
  };

  public class PromTracker(staticGlobalLabels : Text, watermarkResetIntervalSeconds : Nat, now : () -> Nat64) {
    let env : WatermarkEnvironment = (
      watermarkResetIntervalSeconds.toNat64() * 1_000_000_000,
      now,
    );
    type IValue = {
      prefix : Text;
      labels : Text;
      dump : () -> [Metric];
      share : () -> ?StableDataItem;
      unshare : (StableDataItem) -> ();
    };

    let values : List.List<?IValue> = List.empty();

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
      List.add(values, ?value);
      // return the interface
      {
        value = pull;
        remove = func() = removeValueById_(id);
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
        remove = func() = removeValueById_(id);
      };
    };

    /// Register a GaugeValue in the tracker.
    /// A GaugeValue is stateful. It's value can be updated by overwriting it's previous value.
    /// A GaugeValue keeps some information about it's history such as high and low watermarks
    /// and histogram buckets counters that can be used to create heatmaps.
    ///
    /// If the 4-th argument is an empty list then no histogram buckets are tracked.
    /// ```motoko
    /// let requestDuration = tracker.addGauge("request_duration", "", #both, ?[50, 110], false);
    /// requestDuration.update(123);
    /// requestDuration.update(101);
    /// // now it will output stats:
    /// // request_duration_sum: 224
    /// // request_duration_count: 2
    /// // request_duration_high_watermark: 123
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
        remove = func() = removeValueById_(gaugeId);
      };
    };

    /// Register a HeatmapValue in the tracker.
    /// A HeatmapValue is stateful. It's values can be updated by adding/removing/updating particular entries.
    /// A HeatmapValue does not store entries themselves. It is the responsibility of client code to update/remove them correctly
    /// A HeatmapValue stores histogram buckets counters with limits 0 and powers of 2. Buckets amount increases automatically
    /// when big entry is added and never shrinks.
    ///
    /// Entry values have to be in Nat64 range [0;2^64-1]
    ///
    /// ```motoko
    /// let payloadSizes = tracker.addHeatmap("payload_sizes", "", false);
    /// payloadSizes.addEntry(50);
    /// payloadSizes.addEntry(20);
    /// // now it will output stats:
    /// // payload_sizes{le="0"}: 0
    /// // payload_sizes{le="1"}: 0
    /// // payload_sizes{le="2"}: 0
    /// // payload_sizes{le="4"}: 0
    /// // payload_sizes{le="8"}: 0
    /// // payload_sizes{le="16"}: 0
    /// // payload_sizes{le="32"}: 1
    /// // payload_sizes{le="64"}: 2
    /// // payload_sizes_count: 2
    /// // payload_sizes_sum: 70
    /// ```
    public func addHeatmap(prefix : Text, labels : Text, isStable : Bool) : HeatmapInterface {
      // create and register the value
      let heatmapId = values.size();
      let heatmapValue = HeatmapValue(prefix, labels, isStable);
      values.add(?heatmapValue);
      // return the interface
      {
        sum = func() = heatmapValue.sum;
        count = func() = heatmapValue.count;
        addEntry = heatmapValue.addEntry;
        removeEntry = heatmapValue.removeEntry;
        updateEntry = heatmapValue.updateEntry;
        remove = func() = removeValueById_(heatmapId);
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
      ignore addPullValue("rts_upgrade_instructions", "", func() = Prim.rts_upgrade_instructions());
      ignore addPullValue("rts_stable_memory_size", "", func() = Prim.rts_stable_memory_size());
      ignore addPullValue("rts_logical_stable_memory_size", "", func() = Prim.rts_logical_stable_memory_size());

      ignore addPullValue("canister_version", "", func() = Nat64.toNat(Prim.canisterVersion()));
    };

    func removeValueById_(id : Nat) : () = values.put(id, null);

    public func removeValue(prefix : Text, labels : Text) {
      for ((id, value) in values.enumerate()) {
        switch (value) {
          case (?v) {
            if (v.prefix == prefix and v.labels == labels) {
              removeValueById_(id);
              return;
            };
          };
          case (null) {};
        };
      };
    };

    /// Dump all current metrics to an array
    public func dump() : [Metric] {
      let result = List.empty<Metric>();
      for (v in values.values()) {
        switch (v) {
          case (?value) result.addAll(value.dump().vals());
          case (null) {};
        };
      };
      result.toArray();
    };

    func renderMetric(m : Metric, globalLabels : Text, time : Text) : Text {
      let (metricName, metricLabels, natValue) = m;
      metricName # "{" # concat(globalLabels, metricLabels) # "} "
      # natValue.toText() # " " # time # "\n";
    };

    /// Render all current metrics to prometheus exposition format
    public func renderExposition(dynamicGlobalLabels : Text) : Text {
      let timeStr = (now() / 1_000_000).toText();
      let globalLabels = concat(staticGlobalLabels, dynamicGlobalLabels);
      let lines = Array.map<Metric, Text>(
        dump(),
        func(m) = renderMetric(m, globalLabels, timeStr),
      );
      Text.join(lines.vals(), "");
    };

    private func stablePrefix(v : IValue) : Text = switch (v.labels.size()) {
      case (0) v.prefix;
      case (_) v.prefix # "{}" # v.labels;
    };

    /// Dump all values, marked as stable, to stable data structure
    public func share() : StableData {
      var res : StableData = null;
      for (value in values.values()) {
        switch (value) {
          case (?v) switch (v.share()) {
            case (?data) {
              res := res.pushFront((stablePrefix(v), data));
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
      for (value in values.values()) {
        switch (value) {
          case (?v) switch (data.find(func x = x.0 == stablePrefix(v))) { case (?data) v.unshare(data.1); case (_) {}; }; case (_) {};
        };
      };
    };
  };

  class PullValue(prefix_ : Text, labels_ : Text, pull : () -> Nat) {
    public let prefix = prefix_;
    public let labels = labels_;

    public func dump() : [Metric] = [(prefix, labels, pull())];

    public func share() : ?StableDataItem = null;
    public func unshare(_ : StableDataItem) = ();
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
      ?#counter(value);
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
    public var counters : [var Nat] = VarArray.repeat<Nat>(0, limits.size());
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
        if (enableLowWM) lowWatermark.update(current, t);
        if (enableHighWM) highWatermark.update(current, t);
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
      let all = List.fromArray<Metric>([
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
      all.toArray();
    };

    public func share() : ?StableDataItem {
      if (not isStable) return null;
      ?#gauge(lastValue, count, sum, limits, counters.toArray());
    };

    public func unshare(data : StableDataItem) = switch (data, isStable) {
      case (#gauge(v, c, s, bl, bv), true) {
        lastValue := v;
        count := c;
        sum := s;
        limits := bl;
        counters := bv.toVarArray();
      };
      case (_) {};
    };
  };
  class HeatmapValue(prefix_ : Text, labels_ : Text, isStable : Bool) {
    public let prefix = prefix_;
    public let labels = labels_;

    public var count : Nat = 0;
    public var sum : Nat = 0;
    public var buckets : [var Nat] = [var];

    func getBucketIndex_(entry : Nat) : Nat {
      if (entry == 0) return 0;
      let bits = Nat64.bitcountLeadingZero(Nat64.fromNat(entry - 1));
      return 65 - bits.toNat();
    };

    func getLimit_(bucket : Nat) : Nat64 {
      var pow2 : Nat64 = 0;
      if (bucket > 0) {
        pow2 := 1 << Nat64.fromNat(bucket - 1);
      };
      pow2;
    };

    func allocateBucketFor_(entry : Nat) : Nat {
      let bucket = getBucketIndex_(entry);
      if (buckets.size() < bucket + 1) {
        buckets := VarArray.tabulate<Nat>(
          bucket + 1,
          func(i) {
            if (i < buckets.size()) return buckets[i];
            0;
          },
        );
      };
      bucket;
    };

    public func addEntry(entry : Nat) {
      count += 1;
      sum += entry;
      buckets[allocateBucketFor_(entry)] += 1;
    };

    public func removeEntry(entry : Nat) {
      count -= 1;
      sum -= entry;
      buckets[allocateBucketFor_(entry)] -= 1;
    };

    public func updateEntry(oldEntryValue : Nat, newEntryValue : Nat) {
      sum += newEntryValue;
      sum -= oldEntryValue;
      let oldBucket = allocateBucketFor_(oldEntryValue);
      let newBucket = allocateBucketFor_(newEntryValue);
      if (oldBucket == newBucket) return;
      buckets[oldBucket] -= 1;
      buckets[newBucket] += 1;
    };

    public func dump() : [Metric] {
      var aggregatedCounter = 0;
      Array.tabulate<Metric>(
        buckets.size() + 2,
        func(i) {
          if (i < buckets.size()) {
            aggregatedCounter += buckets[i];
            (prefix, concat(labels, "le=\"" # (getLimit_(i)).toText() # "\""), aggregatedCounter);
          } else if (i == buckets.size()) {
            (prefix # "_count", labels, count);
          } else {
            (prefix # "_sum", labels, sum);
          };
        },
      );
    };

    public func share() : ?StableDataItem {
      if (not isStable) return null;
      ?#heatmap(sum, count, buckets.toArray());
    };

    public func unshare(data : StableDataItem) = switch (data, isStable) {
      case (#heatmap(s, c, b), true) {
        sum := s;
        count := c;
        buckets := b.toVarArray();
      };
      case (_) {};
    };
  };
};
