import PT "../src/lib";
import { Counter; Gauge; Heatmap } "../src/Metrics";

import Suite "mo:motoko-matchers/Suite";
import T "mo:motoko-matchers/Testable";
import M "mo:motoko-matchers/Matchers";
import Nat "mo:core/Nat";
import Debug "mo:core/Debug";

let { run; test; suite } = Suite;

let pt = PT.new();
pt.setHoldDown(5);
let renderer = PT.Renderer(pt);

// Helper functions
func find(metrics : [(Text, Text, Nat)], name : Text, labels : Text) : ?Nat {
  for (m in metrics.vals()) {
    if (m.0 == name and m.1 == labels) return ?m.2;
  };
  null;
};
func expect(metrics : [(Text, Text, Nat)], name : Text, labels : Text, value : Nat) : Bool {
  switch (find(metrics, name, labels)) {
    case (?v) {
      if (v == value) {
        true;
      } else {
        Debug.print("Expect failed for metric '" # name # "': expected " # Nat.toText(value) # ", found " # Nat.toText(v));
        false;
      };
    };
    case (null) {
      Debug.print("Expect failed for metric '" # name # "': not found");
      false;
    };
  };
};
func expectExists(metrics : [(Text, Text, Nat)], name : Text, labels : Text, exists : Bool) : Bool {
  switch (find(metrics, name, labels)) {
    case (?_) exists;
    case (null) not exists;
  };
};

/* --------------------------------------- */
// Pull value basic
let pvId = renderer.addPullValue(PT.newPullValue("test_val_0", [], func() = 150));
run(
  test(
    "pull value output",
    expect(renderer.read(), "test_val_0", "", 150),
    M.equals(T.bool(true)),
  )
);

/* --------------------------------------- */
// Remove pull value
renderer.removePullValue(pvId);
run(
  test(
    "value removed",
    renderer.read().size(),
    M.equals(T.nat(0)),
  )
);

/* --------------------------------------- */
// Pull value with labels
let pvId2 = renderer.addPullValue(PT.newPullValue("test_val_1", [("foo", "bar")], func() = 270));
run(
  test(
    "pull value labels",
    expect(renderer.read(), "test_val_1", "foo=\"bar\"", 270),
    M.equals(T.bool(true)),
  )
);
renderer.removePullValue(pvId2);

/* --------------------------------------- */
// Counter
let counter = pt.newCounter("test_counter", []);
run(
  test(
    "initial counter state (0)",
    expect(renderer.read(), "test_counter", "", 0),
    M.equals(T.bool(true)),
  )
);
counter.add(3);
run(
  test(
    "counter add 3",
    expect(renderer.read(), "test_counter", "", 3),
    M.equals(T.bool(true)),
  )
);
counter.add(4);
run(
  test(
    "counter add 4 => 7",
    expect(renderer.read(), "test_counter", "", 7),
    M.equals(T.bool(true)),
  )
);
counter.sub(2);
run(
  test(
    "counter sub 2 => 5",
    expect(renderer.read(), "test_counter", "", 5),
    M.equals(T.bool(true)),
  )
);
counter.set(2);
run(
  test(
    "counter set 2",
    expect(renderer.read(), "test_counter", "", 2),
    M.equals(T.bool(true)),
  )
);
pt.removeValue(counter);
run(
  test(
    "counter removed",
    expectExists(renderer.read(), "test_counter", "", false), // should now be missing
    M.equals(T.bool(true)),
  )
);

/* --------------------------------------- */
// Counter with labels
let counter1 = pt.newCounter("test_counter_1", [("foo", "bar")]);
run(
  test(
    "counter labels initial 0",
    expect(renderer.read(), "test_counter_1", "foo=\"bar\"", 0),
    M.equals(T.bool(true)),
  )
);
pt.removeValue(counter1);

/* --------------------------------------- */
// Gauge without buckets
let gauge = PT.newGauge(pt, "test_gauge", [], []);
run(
  test(
    "initial gauge state (no buckets)",
    // Watermarks are not rendered before first update, so only last/sum/count = 0
    expect(renderer.read(), "test_gauge_last", "", 0) and
    expect(renderer.read(), "test_gauge_sum", "", 0) and
    expect(renderer.read(), "test_gauge_count", "", 0),
    M.equals(T.bool(true)),
  )
);

gauge.update(200);
gauge.update(250);
gauge.update(230);
gauge.update(280);
gauge.update(120);
gauge.update(160);

run(
  suite(
    "gauge state",
    [
      test(
        "gauge aggregates",
        expect(renderer.read(), "test_gauge_last", "", 160) and
        expect(renderer.read(), "test_gauge_sum", "", 1240) and
        expect(renderer.read(), "test_gauge_count", "", 6),
        M.equals(T.bool(true)),
      ),
      test(
        "gauge watermarks",
        expect(renderer.read(), "test_gauge_high_watermark", "", 280) and
        expect(renderer.read(), "test_gauge_low_watermark", "", 120),
        M.equals(T.bool(true)),
      ),
    ],
  )
);

pt.removeValue(gauge);

/* --------------------------------------- */
// Gauge with buckets
let gaugeWithBuckets = PT.newGauge(pt, "buckets_gauge", [], [10, 20, 50, 120, 180]);
run(
  test(
    "initial gauge with buckets",
    // Buckets render even when empty; watermarks do not before first update
    expect(renderer.read(), "buckets_gauge_last", "", 0) and
    expect(renderer.read(), "buckets_gauge_sum", "", 0) and
    expect(renderer.read(), "buckets_gauge_count", "", 0) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"10\"", 0) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"20\"", 0) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"+Inf\"", 0),
    M.equals(T.bool(true)),
  )
);

gaugeWithBuckets.update(35);
gaugeWithBuckets.update(65);
gaugeWithBuckets.update(21);
gaugeWithBuckets.update(1);
gaugeWithBuckets.update(180);
gaugeWithBuckets.update(999999);

run(
  test(
    "gauge with buckets after updates",
    expect(renderer.read(), "buckets_gauge_last", "", 999999) and
    expect(renderer.read(), "buckets_gauge_sum", "", 1000301) and
    expect(renderer.read(), "buckets_gauge_count", "", 6) and
    expect(renderer.read(), "buckets_gauge_high_watermark", "", 999999) and
    expect(renderer.read(), "buckets_gauge_low_watermark", "", 1) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"10\"", 1) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"20\"", 1) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"50\"", 3) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"120\"", 4) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"180\"", 5) and
    expect(renderer.read(), "buckets_gauge_bucket", "le=\"+Inf\"", 6),
    M.equals(T.bool(true)),
  )
);

pt.removeValue(gaugeWithBuckets);

/* --------------------------------------- */
// Labeled gauge with buckets
let gaugeWithLabels = PT.newGauge(pt, "labels_gauge", [("foo", "bar")], [10, 20, 50, 120, 180]);
run(
  test(
    "gauge with bucket labels initial",
    expect(renderer.read(), "labels_gauge_last", "foo=\"bar\"", 0) and
    expect(renderer.read(), "labels_gauge_sum", "foo=\"bar\"", 0) and
    expect(renderer.read(), "labels_gauge_count", "foo=\"bar\"", 0) and
    expect(renderer.read(), "labels_gauge_bucket", "foo=\"bar\",le=\"10\"", 0) and
    expect(renderer.read(), "labels_gauge_bucket", "foo=\"bar\",le=\"20\"", 0) and
    expect(renderer.read(), "labels_gauge_bucket", "foo=\"bar\",le=\"+Inf\"", 0),
    M.equals(T.bool(true)),
  )
);
pt.removeValue(gaugeWithLabels);

/* --------------------------------------- */
// Heatmap
let heatmap = PT.newHeatmap(pt, "test_heatmap", []);
run(
  suite(
    "initial heatmap state",
    [
      test(
        "initial heatmap count/sum",
        expect(renderer.read(), "test_heatmap_count", "", 0) and
        expect(renderer.read(), "test_heatmap_sum", "", 0),
        M.equals(T.bool(true)),
      ),
    ],
  )
);

heatmap.add(100);
heatmap.add(0);
heatmap.add(3);
heatmap.add(64);

run(
  test(
    "heatmap buckets after adds",
    // Buckets are cumulative
    expect(renderer.read(), "test_heatmap_bucket", "le=\"0\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"1\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"2\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"4\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"8\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"16\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"32\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"64\"", 3) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"128\"", 4) and
    expect(renderer.read(), "test_heatmap_count", "", 4) and
    expect(renderer.read(), "test_heatmap_sum", "", 167),
    M.equals(T.bool(true)),
  )
);

heatmap.update(3, 103);
run(
  test(
    "heatmap after update (3 -> 103)",
    expect(renderer.read(), "test_heatmap_bucket", "le=\"0\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"1\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"2\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"4\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"8\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"16\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"32\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"64\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"128\"", 4) and
    expect(renderer.read(), "test_heatmap_count", "", 4) and
    expect(renderer.read(), "test_heatmap_sum", "", 267),
    M.equals(T.bool(true)),
  )
);

heatmap.update(103, 96);
run(
  test(
    "heatmap after update (103 -> 96)",
    expect(renderer.read(), "test_heatmap_bucket", "le=\"0\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"1\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"2\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"4\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"8\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"16\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"32\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"64\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"128\"", 4) and
    expect(renderer.read(), "test_heatmap_count", "", 4) and
    expect(renderer.read(), "test_heatmap_sum", "", 260),
    M.equals(T.bool(true)),
  )
);

heatmap.remove(96);
heatmap.remove(100);

run(
  test(
    "heatmap after removes",
    expect(renderer.read(), "test_heatmap_bucket", "le=\"0\"", 1) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"64\"", 2) and
    expect(renderer.read(), "test_heatmap_bucket", "le=\"128\"", 2) and
    expect(renderer.read(), "test_heatmap_count", "", 2) and
    expect(renderer.read(), "test_heatmap_sum", "", 64),
    M.equals(T.bool(true)),
  )
);

pt.removeValue(heatmap);

/* --------------------------------------- */
// Handle underflows
let underflowedCounter = pt.newCounter("test_counter", []);

underflowedCounter.add(3);
run(
  test(
    "counter add 3",
    expect(renderer.read(), "test_counter", "", 3) and
    expectExists(renderer.read(), "test_counter_negative", "", false),
    M.equals(T.bool(true)),
  )
);

underflowedCounter.sub(7);
run(
  test(
    "counter -4",
    expect(renderer.read(), "test_counter", "", 4) and
    expect(renderer.read(), "test_counter_negative", "", 1),
    M.equals(T.bool(true)),
  )
);

underflowedCounter.add(5);
run(
  test(
    "counter positive again",
    expect(renderer.read(), "test_counter", "", 1) and
    expectExists(renderer.read(), "test_counter_negative", "", false),
    M.equals(T.bool(true)),
  )
);

pt.removeValue(underflowedCounter);

// heatmap underflows
let heatmap2 = PT.newHeatmap(pt, "test_heatmap_underflow", []);
heatmap2.add(7);
heatmap2.add(9);
// intended misuse
heatmap2.remove(3);

run(
  test(
    "bad remove",
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"0\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"1\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"2\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"4\"", 1) and
    expect(renderer.read(), "test_heatmap_underflow_bucket_negative", "le=\"4\"", 1) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"8\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"16\"", 1) and
    expect(renderer.read(), "test_heatmap_underflow_count", "", 1) and
    expect(renderer.read(), "test_heatmap_underflow_sum", "", 13),
    M.equals(T.bool(true)),
  )
);

// should get back to normal state if fixed (added back incorrectly removed value)
heatmap2.add(3);
run(
  test(
    "state recovery",
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"0\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"1\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"2\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"4\"", 0) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"8\"", 1) and
    expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"16\"", 2) and
    expect(renderer.read(), "test_heatmap_underflow_count", "", 2) and
    expect(renderer.read(), "test_heatmap_underflow_sum", "", 16),
    M.equals(T.bool(true)),
  )
);

// sum and count should also handle underflows
heatmap2.remove(15);
heatmap2.remove(15);
heatmap2.remove(15);
run(
  test(
    "count/sum underflow",
    expect(renderer.read(), "test_heatmap_underflow_count", "", 1) and
    expect(renderer.read(), "test_heatmap_underflow_count_negative", "", 1) and
    expect(renderer.read(), "test_heatmap_underflow_sum", "", 29) and
    expect(renderer.read(), "test_heatmap_underflow_sum_negative", "", 1),
    M.equals(T.bool(true)),
  )
);

pt.removeValue(heatmap2);
