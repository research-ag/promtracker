import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Testable "testable";

module {
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

  let now : () -> Nat64 = func() = Prim.time();

  public type StableData = Testable.StableData;
  public type PullValue = Testable.PullValueInterface;
  public type CounterValue = Testable.CounterInterface;
  public type GaugeValue = Testable.GaugeInterface;
  public type HeatmapValue = Testable.HeatmapInterface;

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
  public type PromTracker = Testable.PromTracker;
  public func PromTracker(labels : Text, watermarkResetIntervalSeconds : Nat) : PromTracker {
    Testable.PromTracker(labels, watermarkResetIntervalSeconds, now);
  };

};
