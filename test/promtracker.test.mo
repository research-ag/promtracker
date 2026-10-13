import PT "../src/lib";
import Tracker "../src/Tracker";
import { Counter; Gauge; Heatmap } "../src/Metrics";

import { test; suite } "mo:test";
import Nat "mo:core/Nat";
import Debug "mo:core/Debug";

let pt = Tracker.new();
pt.setHoldDown(5);
let renderer = PT.Renderer();
renderer.addValue(pt.toValue());

// Helper functions
func find(metrics : [(Text, Text, Nat)], name : Text, labels : Text) : ?Nat {
  for (m in metrics.values()) {
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
        Debug.print("Expect failed for metric '" # name # "': expected " # value.toText() # ", found " # v.toText());
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
let pvId = renderer.addValueRef(PT.newValue("test_val_0", [], func() = 150));
test(
  "pull value output",
  func() {
    assert (expect(renderer.read(), "test_val_0", "", 150));
  },
);

/* --------------------------------------- */
// Remove pull value
renderer.removeValue(pvId);
test(
  "value removed",
  func() {
    assert (renderer.read().size() == 0);
  },
);

/* --------------------------------------- */
// Pull value with labels
let pvId2 = renderer.addValueRef(PT.newValue("test_val_1", [("foo", "bar")], func() = 270));
test(
  "pull value labels",
  func() {
    assert (expect(renderer.read(), "test_val_1", "foo=\"bar\"", 270));
  },
);
renderer.removeValue(pvId2);

/* --------------------------------------- */
// Counter
let counter = pt.newCounter("test_counter", []);
test(
  "initial counter state (0)",
  func() {
    assert (expect(renderer.read(), "test_counter", "", 0));
  },
);
counter.add(3);
test(
  "counter add 3",
  func() {
    assert (expect(renderer.read(), "test_counter", "", 3));
  },
);
counter.add(4);
test(
  "counter add 4 => 7",
  func() {
    assert (expect(renderer.read(), "test_counter", "", 7));
  },
);
counter.sub(2);
test(
  "counter sub 2 => 5",
  func() {
    assert (expect(renderer.read(), "test_counter", "", 5));
  },
);
counter.set(2);
test(
  "counter set 2",
  func() {
    assert (expect(renderer.read(), "test_counter", "", 2));
  },
);
counter.unregister();
test(
  "counter removed",
  func() {
    // should now be missing
    assert (expectExists(renderer.read(), "test_counter", "", false));
  },
);

/* --------------------------------------- */
// Counter with labels
let counter1 = pt.newCounter("test_counter_1", [("foo", "bar")]);
test(
  "counter labels initial 0",
  func() {
    assert (expect(renderer.read(), "test_counter_1", "foo=\"bar\"", 0));
  },
);
counter1.unregister();

/* --------------------------------------- */
// Gauge without buckets
let gauge = pt.newGauge("test_gauge", [], []);
test(
  "initial gauge state (no buckets)",
  func() {
    // Watermarks are not rendered before first update, so only last/sum/count = 0
    assert (
      expect(renderer.read(), "test_gauge_last", "", 0) and
      expect(renderer.read(), "test_gauge_sum", "", 0) and
      expect(renderer.read(), "test_gauge_count", "", 0)
    );
  },
);

gauge.update(200);
gauge.update(250);
gauge.update(230);
gauge.update(280);
gauge.update(120);
gauge.update(160);

suite(
  "gauge state",
  func() {
    test(
      "gauge aggregates",
      func() {
        assert (
          expect(renderer.read(), "test_gauge_last", "", 160) and
          expect(renderer.read(), "test_gauge_sum", "", 1240) and
          expect(renderer.read(), "test_gauge_count", "", 6)
        );
      },
    );
    test(
      "gauge watermarks",
      func() {
        assert (
          expect(renderer.read(), "test_gauge_high_watermark", "", 280) and
          expect(renderer.read(), "test_gauge_low_watermark", "", 120)
        );
      },
    );
  },
);

gauge.unregister();

/* --------------------------------------- */
// Gauge with buckets
let gaugeWithBuckets = pt.newGauge("buckets_gauge", [], [10, 20, 50, 120, 180]);
test(
  "initial gauge with buckets",
  func() {
    // Buckets render even when empty; watermarks do not before first update
    assert (
      expect(renderer.read(), "buckets_gauge_last", "", 0) and
      expect(renderer.read(), "buckets_gauge_sum", "", 0) and
      expect(renderer.read(), "buckets_gauge_count", "", 0) and
      expect(renderer.read(), "buckets_gauge_bucket", "le=\"10\"", 0) and
      expect(renderer.read(), "buckets_gauge_bucket", "le=\"20\"", 0) and
      expect(renderer.read(), "buckets_gauge_bucket", "le=\"+Inf\"", 0)
    );
  },
);

gaugeWithBuckets.update(35);
gaugeWithBuckets.update(65);
gaugeWithBuckets.update(21);
gaugeWithBuckets.update(1);
gaugeWithBuckets.update(180);
gaugeWithBuckets.update(999999);

test(
  "gauge with buckets after updates",
  func() {
    assert (
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
      expect(renderer.read(), "buckets_gauge_bucket", "le=\"+Inf\"", 6)
    );
  },
);

gaugeWithBuckets.unregister();

/* --------------------------------------- */
// Labeled gauge with buckets
let gaugeWithLabels = pt.newGauge("labels_gauge", [("foo", "bar")], [10, 20, 50, 120, 180]);
test(
  "gauge with bucket labels initial",
  func() {
    assert (
      expect(renderer.read(), "labels_gauge_last", "foo=\"bar\"", 0) and
      expect(renderer.read(), "labels_gauge_sum", "foo=\"bar\"", 0) and
      expect(renderer.read(), "labels_gauge_count", "foo=\"bar\"", 0) and
      expect(renderer.read(), "labels_gauge_bucket", "foo=\"bar\",le=\"10\"", 0) and
      expect(renderer.read(), "labels_gauge_bucket", "foo=\"bar\",le=\"20\"", 0) and
      expect(renderer.read(), "labels_gauge_bucket", "foo=\"bar\",le=\"+Inf\"", 0)
    );
  },
);
gaugeWithLabels.unregister();

/* --------------------------------------- */
// Heatmap
let heatmap = pt.newHeatmap("test_heatmap", []);
suite(
  "initial heatmap state",
  func() {
    test(
      "initial heatmap count/sum",
      func() {
        assert (
          expect(renderer.read(), "test_heatmap_count", "", 0) and
          expect(renderer.read(), "test_heatmap_sum", "", 0)
        );
      },
    );
  },
);

heatmap.add(100);
heatmap.add(0);
heatmap.add(3);
heatmap.add(64);

test(
  "heatmap buckets after adds",
  func() {
    // Buckets are cumulative
    assert (
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
      expect(renderer.read(), "test_heatmap_sum", "", 167)
    );
  },
);

heatmap.update(3, 103);
test(
  "heatmap after update (3 -> 103)",
  func() {
    assert (
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
      expect(renderer.read(), "test_heatmap_sum", "", 267)
    );
  },
);

heatmap.update(103, 96);
test(
  "heatmap after update (103 -> 96)",
  func() {
    assert (
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
      expect(renderer.read(), "test_heatmap_sum", "", 260)
    );
  },
);

heatmap.remove(96);
heatmap.remove(100);

test(
  "heatmap after removes",
  func() {
    assert (
      expect(renderer.read(), "test_heatmap_bucket", "le=\"0\"", 1) and
      expect(renderer.read(), "test_heatmap_bucket", "le=\"64\"", 2) and
      expect(renderer.read(), "test_heatmap_bucket", "le=\"128\"", 2) and
      expect(renderer.read(), "test_heatmap_count", "", 2) and
      expect(renderer.read(), "test_heatmap_sum", "", 64)
    );
  },
);

heatmap.unregister();

/* --------------------------------------- */
// Handle underflows
let underflowedCounter = pt.newCounter("test_counter", []);

underflowedCounter.add(3);
test(
  "counter add 3",
  func() {
    assert (
      expect(renderer.read(), "test_counter", "", 3) and
      expectExists(renderer.read(), "test_counter_negative", "", false)
    );
  },
);

underflowedCounter.sub(7);
test(
  "counter -4",
  func() {
    assert (
      expect(renderer.read(), "test_counter", "", 4) and
      expect(renderer.read(), "test_counter_negative", "", 1)
    );
  },
);

underflowedCounter.add(5);
test(
  "counter positive again",
  func() {
    assert (
      expect(renderer.read(), "test_counter", "", 1) and
      expectExists(renderer.read(), "test_counter_negative", "", false)
    );
  },
);

underflowedCounter.unregister();

// heatmap underflows
let heatmap2 = pt.newHeatmap("test_heatmap_underflow", []);
heatmap2.add(7);
heatmap2.add(9);
// intended misuse
heatmap2.remove(3);

test(
  "bad remove",
  func() {
    assert (
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"0\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"1\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"2\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"4\"", 1) and
      expect(renderer.read(), "test_heatmap_underflow_bucket_negative", "le=\"4\"", 1) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"8\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"16\"", 1) and
      expect(renderer.read(), "test_heatmap_underflow_count", "", 1) and
      expect(renderer.read(), "test_heatmap_underflow_sum", "", 13)
    );
  },
);

// should get back to normal state if fixed (added back incorrectly removed value)
heatmap2.add(3);
test(
  "state recovery",
  func() {
    assert (
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"0\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"1\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"2\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"4\"", 0) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"8\"", 1) and
      expect(renderer.read(), "test_heatmap_underflow_bucket", "le=\"16\"", 2) and
      expect(renderer.read(), "test_heatmap_underflow_count", "", 2) and
      expect(renderer.read(), "test_heatmap_underflow_sum", "", 16)
    );
  },
);

// sum and count should also handle underflows
heatmap2.remove(15);
heatmap2.remove(15);
heatmap2.remove(15);
test(
  "count/sum underflow",
  func() {
    assert (
      expect(renderer.read(), "test_heatmap_underflow_count", "", 1) and
      expect(renderer.read(), "test_heatmap_underflow_count_negative", "", 1) and
      expect(renderer.read(), "test_heatmap_underflow_sum", "", 29) and
      expect(renderer.read(), "test_heatmap_underflow_sum_negative", "", 1)
    );
  },
);

heatmap2.unregister();
