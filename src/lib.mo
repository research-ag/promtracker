import Array "mo:core/Array";
import List "mo:core/List";
import Nat_ "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Nat32 "mo:core/Nat32";
import Principal "mo:core/Principal";
import PureList_ "mo:core/pure/List";
import Text_ "mo:core/Text";
import Types "mo:core/Types";
import VarArray "mo:core/VarArray";
import Prim "mo:prim";

module {
  /// Helper function to get the first 5 characters of the canister's
  /// own canister id (by passing itself to this function).
  public func shortName(a : actor {}) : Text {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Prim.trap("");
    name;
  };

  /// Helper function to create a canister label in the form:
  ///   `canister="abcde"`
  /// if the canister id starts with `abcde-...`.
  public type Labels = [(Text, Text)];

  public func canisterLabel(a : actor {}) : Labels {
    [("canister", shortName(a))];
  };

  /// Helper function to create a list of bucket limits:
  /// `[a + d, .., a + n * d]`
  /// which represents `n` buckets plus the `+Inf` bucket.
  public func limits(a : Nat, n : Nat, d : Nat) : [Nat] {
    Array.tabulate<Nat>(n, func(i) = a + (i + 1) * d);
  };

  /// Default value for implicit `now` argument in the `PromTracker` constructor
  public let now : () -> Nat64 = Prim.time;

  // Validate that a Text contains only [A-Za-z0-9_]
  func isAllowedAscii_(t : Text) : Bool {
    label l for (c in t.chars()) {
      let n = Nat32.toNat(Prim.charToNat32(c));
      if (
        not (
          (n >= 48 and n <= 57) // 0-9
          or (n >= 65 and n <= 90) // A-Z
          or (n >= 97 and n <= 122) // a-z
          or (n == 95) // _
        )
      ) return false;
    };
    true;
  };

  func validateAlias_(name : Text, kind : { #metric; #lbl }) {
    let msgKind = switch (kind) {
      case (#metric) "metric name";
      case (#lbl) "label key";
    };
    let ?first = name.chars().next() else Prim.trap("Invalid " # msgKind # ": must match [A-Za-z_][A-Za-z0-9_]*, got empty string");
    let n = Nat32.toNat(Prim.charToNat32(first));
    if (n >= 48 and n <= 57) {
      Prim.trap("Invalid " # msgKind # ": cannot start with a digit, got: \"" # name # "\"");
    };
    if (not isAllowedAscii_(name)) {
      Prim.trap("Invalid " # msgKind # ": only [A-Za-z0-9_] allowed, got: \"" # name # "\"");
    };
  };

  func validateLabels_(labels : Labels) {
    for ((k, _v) in labels.vals()) {
      validateAlias_(k, #lbl);
    };
  };

  func escapeLabelValue_(t : Text) : Text {
    var out = "";
    for (c in t.chars()) {
      if (c == '\"') {
        out #= "\\\""; // becomes \"
      } else {
        out #= Text_.fromChar(c);
      };
    };
    out;
  };

  func renderLabels(labels : Labels) : Text {
    var first = true;
    var out = "";
    for ((k, v) in labels.vals()) {
      if (first) { first := false } else { out #= "," };
      out #= k # "=\"" # escapeLabelValue_(v) # "\"";
    };
    out;
  };

  func mergeLabels(a : Labels, b : Labels) : Labels {
    Array.concat<(Text, Text)>(a, b);
  };

  func extendLabel(labels : Labels, pair : (Text, Text)) : Labels {
    Array.concat<(Text, Text)>(labels, [pair]);
  };

  type StableDataItem = {
    #counter : Nat;
    #gauge : (Nat, Nat, Nat, [Nat], [Nat]);
    #heatmap : (Nat, Nat, [Nat]);
  };

  /// Stable data type returned by `share()` function
  public type StableData = Types.Pure.List<(Text, StableDataItem)>;

  // The data in type Metric is (name, labels, value)
  type Metric = (Text, Labels, Nat);

  // The two components of the watermark environment are:
  // - a function returning the hold period in nanoseconds as `Nat64`
  // - a function returning the current time in nanoseconds as `Nat64`
  // After the hold period has passed, the watermark can be updated to any (lower) value.
  type WatermarkEnvironment = (() -> Nat64, () -> Nat64);

  /// The access interface for pull values
  public type PullValue = {
    value : () -> Nat;
    remove : () -> ();
  };

  /// The access interface for counter values
  /// Warning: Counter silently prevents underflow on `sub` operation by setting the counter value to zero.
  /// This can lead to unexpected values after such an event.
  public type Counter = {
    value : () -> Nat;
    set : (x : Nat) -> ();
    add : (x : Nat) -> ();
    sub : (x : Nat) -> ();
    remove : () -> ();
  };

  /// The access interface for gauge values
  public type Gauge = {
    value : () -> Nat;
    sum : () -> Nat;
    count : () -> Nat;
    update : (x : Nat) -> ();
    remove : () -> ();
  };

  /// The access interface for heatmap values
  /// Warning: `removeEntry` and `updateEntry` can trap if you are removing/updating
  /// an entry that was not previously added.
  public type Heatmap = {
    sum : () -> Nat;
    count : () -> Nat;
    addEntry : (Nat) -> ();
    removeEntry : (Nat) -> ();
    updateEntry : (oldValue : Nat, newValue : Nat) -> ();
    remove : () -> ();
  };

  /// Value tracker, designed specifically for use as a source for Prometheus.
  ///
  /// Example:
  /// ```motoko
  /// let tracker = PromTracker.PromTracker([]);
  /// ....
  /// let successfulHeartbeats = tracker.addCounter("successful_heartbeats", [], true);
  /// let failedHeartbeats = tracker.addCounter("failed_heartbeats", [], true);
  /// let heartbeats = tracker.addPullValue("heartbeats", [], func() = successfulHeartbeats.value() + failedHeartbeats.value());
  /// let heartbeatDuration = tracker.addGauge("heartbeat_duration", [], #both, [], false);
  /// ....
  /// // update values from your code
  /// successfulHeartbeats.add(2);
  /// failedHeartbeats.add(1);
  /// heartbeatDuration.update(10);
  /// heartbeatDuration.update(18);
  /// heartbeatDuration.update(14);
  /// ....
  /// // get prometheus metrics:
  /// let text = tracker.renderExposition();
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
  /// The first argument `globalLabels` is a list of label pairs (`[(Text, Text)]`) that will be added as global labels to each metric.
  /// For example, pass `PT.canisterLabel(self)` or `[("canister", "my_name")]` to include a `canister="..."` label on every metric.
  ///
  /// The second argument `now` should not be passed explicitly in normal use.
  /// It has an implicit default value.
  /// Resetting it is reserved for internal testing purposes.
  ///
  /// For executable examples see the various examples in `examples/`.
  public class PromTracker(
    globalLabels : Labels,
    now : (implicit : () -> Nat64),
  ) {
    // Validate global labels once at construction
    do { validateLabels_(globalLabels) };

    // By default the PromTracker is configured for a 5-minute scraping interval
    // The watermark hold-down period is therefore 5 minutes plus a 5 second margin
    var holdPeriod : Nat64 = 305_000_000_000;

    let env : WatermarkEnvironment = (
      func _ = holdPeriod,
      now,
    );

    type IValue = {
      prefix : Text;
      labels : Labels;
      dump : () -> [Metric];
      share : () -> ?StableDataItem;
      unshare : (StableDataItem) -> ();
    };

    let values : List.List<?IValue> = List.empty();

    /// Set the hold-down period for watermarks in seconds.
    ///
    /// A high watermark with a 5-minute hold-down period means: once set,
    /// the watermark cannot be replaced by a lower value for at least five
    /// minutes, though higher values may replace it immediately.
    public func setWatermarkHoldPeriod(holdSeconds : Nat) {
      holdPeriod := holdSeconds.toNat64() * 1_000_000_000;
    };

    /// Register a PullValue in the tracker.
    /// A PullValue is stateless.
    /// It is calculated dynamically by calling the `pull` function that is provided as a constructor argument.
    ///
    /// Example:
    /// ```motoko
    /// let storageSize = tracker.addPullValue("storage_size", [], func() = storage.size());
    /// ```
    public func addPullValue(prefix : Text, labels : Labels, pull : () -> Nat) : PullValue {
      validateAlias_(prefix, #metric);
      validateLabels_(labels);
      // create and register the value
      let id = values.size();
      let value = PullValueClass(prefix, labels, pull);
      values.add(?value);
      // return the interface
      {
        value = pull;
        remove = func() = removeValueById_(id);
      };
    };

    /// Register a CounterValue in the tracker.
    /// A CounterValue is stateful. It is either set to a concrete value or incremented by a delta.
    ///
    /// A CounterValue can be declared stable by setting the third argument to `true`.
    /// In this case it will be preserved across canister upgrades.
    ///
    /// Example:
    /// ```motoko
    /// let requestsAmount = tracker.addCounter("requests_amount", [], true);
    /// ....
    /// requestsAmount.add(3);
    /// requestsAmount.add(1);
    /// ```
    public func addCounter(prefix : Text, labels : Labels, isStable : Bool) : Counter {
      validateAlias_(prefix, #metric);
      validateLabels_(labels);
      // create and register the value
      let id = values.size();
      let value = CounterValueClass(prefix, labels, isStable);
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
    /// A GaugeValue is stateful. Its value can be updated by overwriting its previous value.
    /// A GaugeValue keeps some information about its history such as high and low watermarks
    /// and histogram buckets counters that can be used to create heatmaps.
    ///
    /// If the 4-th argument is an empty list then no histogram buckets are tracked.
    /// ```motoko
    /// let requestDuration = tracker.addGauge("request_duration", "", #both, [50, 110], false);
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
    public func addGauge(prefix : Text, labels : Labels, watermarks : { #none; #low; #high; #both }, bucketLimits : [Nat], isStable : Bool) : Gauge {
      validateAlias_(prefix, #metric);
      validateLabels_(labels);
      // check order of buckets
      let l = bucketLimits;
      var i = 1;
      while (i < l.size()) {
        if (l[i - 1] >= l[i]) Prim.trap("Bucket limits have to be strictly increasing");
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
      let gaugeValue = GaugeValueClass(prefix, labels, lowWM, highWM, bucketLimits, env, isStable);
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
    /// A HeatmapValue is stateful. Its values can be updated by adding/removing/updating particular entries.
    /// A HeatmapValue does not store entries themselves. It is the responsibility of client code to update/remove them correctly.
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
    public func addHeatmap(prefix : Text, labels : Labels, isStable : Bool) : Heatmap {
      validateAlias_(prefix, #metric);
      validateLabels_(labels);
      // create and register the value
      let heatmapId = values.size();
      let heatmapValue = HeatmapValueClass(prefix, labels, isStable);
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

    /// Add system metrics, such as:
    ///
    /// * Cycle balance
    /// * Canister version (state nonce)
    /// * All numerical `rts_` values (memory, heap sizes, etc.)
    public func addSystemValues() {
      ignore addPullValue("cycles_balance", [], func() = Prim.cyclesBalance());
      ignore addPullValue("canister_version", [], func() = Prim.canisterVersion().toNat());
      ignore addPullValue("rts_memory_size", [], func() = Prim.rts_memory_size());
      ignore addPullValue("rts_heap_size", [], func() = Prim.rts_heap_size());
      ignore addPullValue("rts_total_allocation", [], func() = Prim.rts_total_allocation());
      ignore addPullValue("rts_reclaimed", [], func() = Prim.rts_reclaimed());
      ignore addPullValue("rts_max_live_size", [], func() = Prim.rts_max_live_size());
      ignore addPullValue("rts_max_stack_size", [], func() = Prim.rts_max_stack_size());
      ignore addPullValue("rts_callback_table_count", [], func() = Prim.rts_callback_table_count());
      ignore addPullValue("rts_callback_table_size", [], func() = Prim.rts_callback_table_size());
      ignore addPullValue("rts_mutator_instructions", [], func() = Prim.rts_mutator_instructions());
      ignore addPullValue("rts_collector_instructions", [], func() = Prim.rts_collector_instructions());
      ignore addPullValue("rts_upgrade_instructions", [], func() = Prim.rts_upgrade_instructions());
      ignore addPullValue("rts_stable_memory_size", [], func() = Prim.rts_stable_memory_size());
      ignore addPullValue("rts_logical_stable_memory_size", [], func() = Prim.rts_logical_stable_memory_size());
    };

    func removeValueById_(id : Nat) : () = values.put(id, null);

    /// Remove a previously added value by its prefix and labels
    /// (both must match).
    public func removeValue(prefix : Text, labels : Labels) {
      for ((id, value) in values.enumerate()) {
        switch (value) {
          case (?v) {
            if (v.prefix == prefix and eqLabels(v.labels, labels)) {
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

    func renderMetric(m : Metric, globalLabels : Labels, time : Text) : Text {
      let (metricName, metricLabels, natValue) = m;
      let labelsText = renderLabels(mergeLabels(globalLabels, metricLabels));
      metricName # "{" # labelsText # "} " # natValue.toText() # " " # time # "\n";
    };

    /// Render all current metrics to prometheus exposition format
    public func renderExposition() : Text {
      let timeStr = (now() / 1_000_000).toText();
      let lines = Array.map<Metric, Text>(
        dump(),
        func(m) = renderMetric(m, globalLabels, timeStr),
      );
      lines.vals().join("");
    };

    func eqLabels(a : Labels, b : Labels) : Bool {
      if (a.size() != b.size()) return false;
      var i = 0;
      while (i < a.size()) {
        if (a[i].0 != b[i].0 or a[i].1 != b[i].1) return false;
        i += 1;
      };
      true;
    };

    private func stablePrefix(v : IValue) : Text = switch (v.labels.size()) {
      case (0) v.prefix;
      case (_) v.prefix # "{}" # renderLabels(v.labels);
    };

    /// Export all values, marked as stable, to stable data structure
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
          case (?v) switch (data.find(func x = x.0 == stablePrefix(v))) {
            case (?data) v.unshare(data.1);
            case (_) {};
          };
          case (_) {};
        };
      };
    };
  };

  class PullValueClass(prefix_ : Text, labels_ : Labels, pull : () -> Nat) {
    public let prefix = prefix_;
    public let labels = labels_;

    public func dump() : [Metric] = [(prefix, labels, pull())];

    public func share() : ?StableDataItem = null;
    public func unshare(_ : StableDataItem) = ();
  };

  class CounterValueClass(prefix_ : Text, labels_ : Labels, isStable : Bool) {
    public let prefix = prefix_;
    public let labels = labels_;

    public var value = 0;

    public func add(n : Nat) { value += n };
    public func sub(n : Nat) { if (n > value) value := 0 else value -= n };
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

  class WatermarkTracker<T>(
    initialMark : T,
    isHigher : (new : T, old : T) -> Bool,
    holdPeriod : () -> Nat64,
  ) {
    var lastMarkTime : Nat64 = 0;
    public var mark : T = initialMark;
    public func update(value : T, time : Nat64) {
      if (isHigher(value, mark) or time > lastMarkTime + holdPeriod()) {
        mark := value;
        lastMarkTime := time;
      };
    };
  };
  class GaugeValueClass(
    prefix_ : Text,
    labels_ : Labels,
    enableLowWM : Bool,
    enableHighWM : Bool,
    limits_ : [Nat],
    env : WatermarkEnvironment,
    isStable : Bool,
  ) {
    public let prefix = prefix_;
    public let labels = labels_;

    let (holdPeriod, now) = env;

    public var count : Nat = 0;
    public var sum : Nat = 0;
    var limits = limits_;
    public var counters : [var Nat] = VarArray.repeat<Nat>(0, limits.size());
    public var highWatermark : WatermarkTracker<Nat> = WatermarkTracker<Nat>(0, func(new, old) = new > old, holdPeriod);
    public var lowWatermark : WatermarkTracker<Nat> = WatermarkTracker<Nat>(0, func(new, old) = new < old, holdPeriod);
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

    func metric(suffix : Text, labels : Labels, value : Nat) : Metric {
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
        all.add(metric("bucket", extendLabel(labels, ("le", limits[i].toText())), counters[i]));
      };
      if (counters.size() > 0) {
        all.add(metric("bucket", extendLabel(labels, ("le", "+Inf")), count));
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
  class HeatmapValueClass(prefix_ : Text, labels_ : Labels, isStable : Bool) {
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
            (prefix, extendLabel(labels, ("le", (getLimit_(i)).toText())), aggregatedCounter);
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
