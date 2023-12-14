import Array "mo:base/Array";
import AssocList "mo:base/AssocList";
import Cycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import StableMemory "mo:base/ExperimentalStableMemory";
import Time "mo:base/Time";
import Text "mo:base/Text";

import Vector "mo:vector/Class";

module {

  type StableDataItem = { #counter : Nat };
  public type StableData = AssocList.AssocList<Text, StableDataItem>;

  /// Helper function to get the first 5 characters of the canister's
  /// own canister id (by passing `self` to this function).
  public func shortName(a : actor {}) : Text {
    let s = Principal.toText(Principal.fromActor(a));
    let ?name = Text.split(s, #char '-').next() else Prim.trap("");
    name;
  };

  /// Helper function to create a list of bucket limits.
  /// [a + d, .., a + n * d]
  /// which represents n buckets plus the +Inf bucket. 
  public func limits(a : Nat, n : Nat, d : Nat) : [Nat] {
    Array.tabulate<Nat>(n, func(i) = a + (i + 1) * d);
  };

  let now_ : () -> Nat64 = func() = Nat64.fromIntWrap(Time.now());

  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

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
    remove : () -> ();
  };
  /// An access interface for gauge value
  public type GaugeInterface = {
    value : () -> Nat;
    update : (x : Nat) -> ();
    remove : () -> ();
  };

  // The data in type Metric is (name, labels, value)
  type Metric = (Text, Text, Nat);

  // The two components of the watermark environment are:
  // - the interval after which the watermarks are reset in seconds as Nat
  // - the function that returns the current time in nanoseconds as Nat64
  type WatermarkEnvironment = (Nat64, () -> Nat64);
  
  /// The constructor PromTracker should be used instead to create this class.
  public class PromTrackerTestable(staticGlobalLabels : Text, watermarkResetIntervalSeconds : Nat, now : () -> Nat64) {
    let env : WatermarkEnvironment = (
      Nat64.fromNat(watermarkResetIntervalSeconds) * 1_000_000_000,
      now,
    );
    type IValue = {
      prefix : Text;
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
    public func addPullValue(prefix : Text, pull : () -> Nat) : PullValueInterface {
      // create and register the value
      let id = values.size();
      let value = PullValue(prefix, pull);
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
    public func addCounter(prefix : Text, isStable : Bool) : CounterInterface {
      // create and register the value
      let id = values.size();
      let value = CounterValue(prefix, isStable);
      values.add(?value);
      // return the interface
      {
        value = func() = value.value;
        set = value.set;
        add = value.add;
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
    public func addGauge(prefix : Text, bucketLimits : [Nat]) : GaugeInterface {
      // check order of buckets
      let l = bucketLimits;
      var i = 1;
      while (i < l.size()) {
        if (l[i - 1] >= l[i]) Prim.trap("Buckets have to be ordered and non-empty");
        i += 1;
      };
      // create and register the value
      let gaugeId = values.size();
      let gaugeValue = GaugeValue(prefix, bucketLimits, env);
      values.add(?gaugeValue);
      // return the interface
      {
        value = func() = gaugeValue.lastValue;
        update = gaugeValue.update;
        remove = func() = removeValue(gaugeId);
      };
    };

    /// Add system metrics, such as cycle balance, memory size, heap size etc.
    public func addSystemValues() {
      ignore addPullValue("cycles_balance", func() = Cycles.balance());
      ignore addPullValue("rts_memory_size", func() = Prim.rts_memory_size());
      ignore addPullValue("rts_heap_size", func() = Prim.rts_heap_size());
      ignore addPullValue("rts_total_allocation", func() = Prim.rts_total_allocation());
      ignore addPullValue("rts_reclaimed", func() = Prim.rts_reclaimed());
      ignore addPullValue("rts_max_live_size", func() = Prim.rts_max_live_size());
      ignore addPullValue("rts_max_stack_size", func() = Prim.rts_max_stack_size());
      ignore addPullValue("rts_callback_table_count", func() = Prim.rts_callback_table_count());
      ignore addPullValue("rts_callback_table_size", func() = Prim.rts_callback_table_size());
      ignore addPullValue("rts_mutator_instructions", func() = Prim.rts_mutator_instructions());
      ignore addPullValue("rts_collector_instructions", func() = Prim.rts_collector_instructions());
      ignore addPullValue("stablememory_size", func() = Nat64.toNat(StableMemory.size()));
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
      /*
      Array.foldLeft<Metric, Text>(
        dump(),
        "",
        func(acc, m) = acc # renderMetric(m, globalLabels, timeStr),
      );
      */
    };

    /// Dump all values, marked as stable, to stable data structure
    public func share() : StableData {
      var res : StableData = null;
      for (value in values.vals()) {
        switch (value) {
          case (?v) switch (v.share()) {
            case (?data) {
              res := AssocList.replace(res, v.prefix, Text.equal, ?data).0;
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
          case (?v) switch (AssocList.find(data, v.prefix, Text.equal)) {
            case (?data) v.unshare(data);
            case (_) {};
          };
          case (_) {};
        };
      };
    };

  };

  /// Value tracker, designed specifically for use as a source for Prometheus.
  ///
  /// Example:
  /// ```motoko
  /// let tracker = PromTracker.PromTracker(65);
  /// // 65 seconds is the recommended interval if prometheus pulls stats with interval 60 seconds
  /// ....
  /// let successfulHeartbeats = tracker.addCounter("successful_heartbeats", true);
  /// let failedHeartbeats = tracker.addCounter("failed_heartbeats", true);
  /// let heartbeats = tracker.addPullValue("heartbeats", func() = successfulHeartbeats.value() + failedHeartbeats.value());
  /// let heartbeatDuration = tracker.addGauge("heartbeat_duration", null);
  /// ....
  /// // update values from your code
  /// successfulHeartbeats.add(2);
  /// failedHeartbeats.add(1);
  /// heartbeatDuration.update(10);
  /// heartbeatDuration.update(18);
  /// heartbeatDuration.update(14);
  /// ....
  /// // get prometheus metrics:
  /// let text = tracker.renderStats();
  /// ```
  ///
  /// Expected output is:
  /// ```
  /// successful_heartbeats{} 2 1698842860811
  /// failed_heartbeats{} 1 1698842860811
  /// heartbeats{} 3 1698842860811
  /// heartbeat_duration_sum{} 42 1698842860811
  /// heartbeat_duration_count{} 3 1698842860811
  /// heartbeat_duration_high_watermark{} 18 1698842860811
  /// heartbeat_duration_low_watermark{} 10 1698842860811
  /// ```
  ///
  /// For an executable example, see `examples/heartrate.mo`.
  type PromTracker = PromTrackerTestable;
  public func PromTracker(labels : Text, watermarkResetIntervalSeconds : Nat) : PromTracker {
    PromTrackerTestable(labels, watermarkResetIntervalSeconds, now_);
  };

  class PullValue(prefix_ : Text, pull : () -> Nat) {
    public let prefix = prefix_;

    public func dump() : [Metric] = [(prefix, "", pull())];

    public func share() : ?StableDataItem = null;
    public func unshare(data : StableDataItem) = ();
  };

  class CounterValue(prefix_ : Text, isStable : Bool) {
    public let prefix = prefix_;

    public var value = 0;

    public func add(n : Nat) { value += n };
    public func set(n : Nat) { value := n };

    public func dump() : [Metric] = [(prefix, "", value)];

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
  class GaugeValue(prefix_ : Text, limits : [Nat], env : WatermarkEnvironment) {
    public let prefix = prefix_;
    let (resetInterval, now) = env;

    func metric(suffix : Text, labels : Text, value : Nat) : Metric {
      (prefix # "_" # suffix, labels, value);
    };

    public var count : Nat = 0;
    public var sum : Nat = 0;
    public let counters : [var Nat] = Array.init<Nat>(limits.size(), 0);
    public var highWatermark : WatermarkTracker<Nat> = WatermarkTracker<Nat>(0, func(new, old) = new > old, resetInterval);
    public var lowWatermark : WatermarkTracker<Nat> = WatermarkTracker<Nat>(0, func(new, old) = new < old, resetInterval);
    public var lastValue : Nat = 0;

    public func update(current : Nat) {
      lastValue := current;
      // main counters
      count += 1;
      sum += current;
      // watermarks
      let t = now();
      highWatermark.update(current, t);
      lowWatermark.update(current, t);
      // bucket counters
      var n = limits.size();
      while (n > 0) {
        n -= 1;
        if (current > limits[n]) return;
        counters[n] += 1;
      };
    };

    public func dump() : [Metric] {
      let all = Vector.fromArray<Metric>([
        metric("last", "", lastValue),
        metric("sum", "", sum),
        metric("count", "", count),
        metric("high_watermark", "", highWatermark.mark),
        metric("low_watermark", "", lowWatermark.mark),
      ]);
      for (i in counters.keys()) {
        all.add(metric("bucket", "le=\"" # Nat.toText(limits[i]) # "\"", counters[i]));
      };
      if (counters.size() > 0) {
        all.add(metric("bucket", "le=\"+Inf\"", count));
      };
      Vector.toArray(all);
    };

    // sharing is disabled for GaugeValue
    public func share() : ?StableDataItem = null;
    public func unshare(data : StableDataItem) = ();
  };

};
