import PT "../src/lib";

import Suite "mo:motoko-matchers/Suite";
import T "mo:motoko-matchers/Testable";
import M "mo:motoko-matchers/Matchers";

let { run; test; suite } = Suite;

var mockedTime : Nat64 = 123_000_000_000_000;
var tracker = PT.PromTrackerTestable("", 5, func() = mockedTime);
//PT.now := func() = mockedTime;

/* --------------------------------------- */
let testValue = tracker.addPullValue("test_val_0", "", func() = 150);
run(
  test(
    "pull value output",
    tracker.renderExposition(""),
    M.equals(T.text("test_val_0{} 150 123000000\n")),
  )
);

/* --------------------------------------- */
testValue.remove();
run(
  test(
    "value removed",
    tracker.renderExposition(""),
    M.equals(T.text("")),
  )
);

/* --------------------------------------- */
let testValue1 = tracker.addPullValue("test_val_1", "foo=\"bar\"", func() = 270);
run(
  test(
    "pull value labels",
    tracker.renderExposition(""),
    M.equals(T.text("test_val_1{foo=\"bar\"} 270 123000000\n")),
  )
);
testValue1.remove();

/* --------------------------------------- */
let counter = tracker.addCounter("test_counter", "", false);
run(
  test(
    "initial counter state",
    tracker.renderExposition(""),
    M.equals(T.text("test_counter{} 0 123000000\n")),
  )
);
counter.add(3);
run(
  test(
    "counter state",
    tracker.renderExposition(""),
    M.equals(T.text("test_counter{} 3 123000000\n")),
  )
);
counter.add(4);
run(
  test(
    "counter state",
    tracker.renderExposition(""),
    M.equals(T.text("test_counter{} 7 123000000\n")),
  )
);
counter.sub(2);
run(
  test(
    "counter state",
    tracker.renderExposition(""),
    M.equals(T.text("test_counter{} 5 123000000\n")),
  )
);
counter.set(2);
run(
  test(
    "counter state",
    tracker.renderExposition(""),
    M.equals(T.text("test_counter{} 2 123000000\n")),
  )
);
counter.remove();

/* --------------------------------------- */
let counter1 = tracker.addCounter("test_counter_1", "foo=\"bar\"", false);
run(
  test(
    "counter labels",
    tracker.renderExposition(""),
    M.equals(T.text("test_counter_1{foo=\"bar\"} 0 123000000\n")),
  )
);
counter1.remove();

/* --------------------------------------- */
let gauge = tracker.addGauge("test_gauge", "", #both, [], false);
run(
  suite(
    "initial gauge state",
    [
      test(
        "initial gauge exposition",
        tracker.renderExposition(""),
        M.equals(T.text("test_gauge_last{} 0 123000000
test_gauge_sum{} 0 123000000
test_gauge_count{} 0 123000000
test_gauge_high_watermark{} 0 123000000
test_gauge_low_watermark{} 0 123000000\n")),
      ),
      test(
        "initial gauge value",
        gauge.value(),
        M.equals(T.nat(0)),
      ),
    ],
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
        "gauge state exposition",
        tracker.renderExposition(""),
        M.equals(T.text("test_gauge_last{} 160 123000000
test_gauge_sum{} 1240 123000000
test_gauge_count{} 6 123000000
test_gauge_high_watermark{} 280 123000000
test_gauge_low_watermark{} 120 123000000\n")),
      ),
      test(
        "gauge value",
        gauge.value(),
        M.equals(T.nat(160)),
      ),
    ],
  )
);

gauge.remove();

/* --------------------------------------- */
let gaugeWithBuckets = tracker.addGauge("buckets_gauge", "", #both, [10, 20, 50, 120, 180], false);
run(
  test(
    "initial gauge state",
    tracker.renderExposition(""),
    M.equals(T.text("buckets_gauge_last{} 0 123000000
buckets_gauge_sum{} 0 123000000
buckets_gauge_count{} 0 123000000
buckets_gauge_high_watermark{} 0 123000000
buckets_gauge_low_watermark{} 0 123000000
buckets_gauge_bucket{le=\"10\"} 0 123000000
buckets_gauge_bucket{le=\"20\"} 0 123000000
buckets_gauge_bucket{le=\"50\"} 0 123000000
buckets_gauge_bucket{le=\"120\"} 0 123000000
buckets_gauge_bucket{le=\"180\"} 0 123000000
buckets_gauge_bucket{le=\"+Inf\"} 0 123000000\n")),
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
    "gauge state",
    tracker.renderExposition(""),
    M.equals(T.text("buckets_gauge_last{} 999999 123000000
buckets_gauge_sum{} 1000301 123000000
buckets_gauge_count{} 6 123000000
buckets_gauge_high_watermark{} 999999 123000000
buckets_gauge_low_watermark{} 1 123000000
buckets_gauge_bucket{le=\"10\"} 1 123000000
buckets_gauge_bucket{le=\"20\"} 1 123000000
buckets_gauge_bucket{le=\"50\"} 3 123000000
buckets_gauge_bucket{le=\"120\"} 4 123000000
buckets_gauge_bucket{le=\"180\"} 5 123000000
buckets_gauge_bucket{le=\"+Inf\"} 6 123000000\n")),
  )
);
gaugeWithBuckets.remove();

/* --------------------------------------- */
let gauge2 = tracker.addGauge("buckets_gauge", "", #both, [], false);
gauge2.update(10);
gauge2.update(900);
gauge2.update(90);
run(
  test(
    "gauge state",
    tracker.renderExposition(""),
    M.equals(T.text("buckets_gauge_last{} 90 123000000
buckets_gauge_sum{} 1000 123000000
buckets_gauge_count{} 3 123000000
buckets_gauge_high_watermark{} 900 123000000
buckets_gauge_low_watermark{} 10 123000000\n")),
  )
);
// emulate that 1 second passed. Watermarks should remain the same
mockedTime += 1_000_000_000;
gauge2.update(20);
gauge2.update(800);
gauge2.update(180);
run(
  test(
    "gauge state",
    tracker.renderExposition(""),
    M.equals(T.text("buckets_gauge_last{} 180 123001000
buckets_gauge_sum{} 2000 123001000
buckets_gauge_count{} 6 123001000
buckets_gauge_high_watermark{} 900 123001000
buckets_gauge_low_watermark{} 10 123001000\n")),
  )
);
// emulate that 5 more seconds passed and watermarks invalidated (in tracker we set 5 seconds as TTL for watermarks)
mockedTime += 5_000_000_000;
gauge2.update(20);
gauge2.update(800);
gauge2.update(180);
run(
  test(
    "gauge state",
    tracker.renderExposition(""),
    M.equals(T.text("buckets_gauge_last{} 180 123006000
buckets_gauge_sum{} 3000 123006000
buckets_gauge_count{} 9 123006000
buckets_gauge_high_watermark{} 800 123006000
buckets_gauge_low_watermark{} 20 123006000\n")),
  )
);
gauge2.remove();

/* --------------------------------------- */
let gaugeWithoutWatermarks = tracker.addGauge("dry_gauge", "", #none, [], false);
gaugeWithoutWatermarks.update(20);
gaugeWithoutWatermarks.update(30);
run(
  test(
    "gauge without watermarks",
    tracker.renderExposition(""),
    M.equals(T.text("dry_gauge_last{} 30 123006000
dry_gauge_sum{} 50 123006000
dry_gauge_count{} 2 123006000\n")),
  )
);
gaugeWithoutWatermarks.remove();

/* --------------------------------------- */
let gaugeWithLowWatermark = tracker.addGauge("half_dry_gauge", "", #low, [], false);
gaugeWithLowWatermark.update(20);
gaugeWithLowWatermark.update(30);
run(
  test(
    "gauge with only low watermark",
    tracker.renderExposition(""),
    M.equals(T.text("half_dry_gauge_last{} 30 123006000
half_dry_gauge_sum{} 50 123006000
half_dry_gauge_count{} 2 123006000
half_dry_gauge_low_watermark{} 20 123006000\n")),
  )
);
gaugeWithLowWatermark.remove();

/* --------------------------------------- */
let gaugeWithHighWatermark = tracker.addGauge("half_wet_gauge", "", #high, [], false);
gaugeWithHighWatermark.update(20);
gaugeWithHighWatermark.update(30);
run(
  test(
    "gauge with only low watermark",
    tracker.renderExposition(""),
    M.equals(T.text("half_wet_gauge_last{} 30 123006000
half_wet_gauge_sum{} 50 123006000
half_wet_gauge_count{} 2 123006000
half_wet_gauge_high_watermark{} 30 123006000\n")),
  )
);
gaugeWithHighWatermark.remove();

/* --------------------------------------- */
let gaugeWithLabels = tracker.addGauge("labels_gauge", "foo=\"bar\"", #both, [10, 20, 50, 120, 180], false);
run(
  test(
    "gauge with bucket labels",
    tracker.renderExposition(""),
    M.equals(T.text("labels_gauge_last{foo=\"bar\"} 0 123006000
labels_gauge_sum{foo=\"bar\"} 0 123006000
labels_gauge_count{foo=\"bar\"} 0 123006000
labels_gauge_high_watermark{foo=\"bar\"} 0 123006000
labels_gauge_low_watermark{foo=\"bar\"} 0 123006000
labels_gauge_bucket{foo=\"bar\",le=\"10\"} 0 123006000
labels_gauge_bucket{foo=\"bar\",le=\"20\"} 0 123006000
labels_gauge_bucket{foo=\"bar\",le=\"50\"} 0 123006000
labels_gauge_bucket{foo=\"bar\",le=\"120\"} 0 123006000
labels_gauge_bucket{foo=\"bar\",le=\"180\"} 0 123006000
labels_gauge_bucket{foo=\"bar\",le=\"+Inf\"} 0 123006000\n")),
  )
);
gaugeWithLabels.remove();

/* --------------------------------------- */
let stableGauge1 = tracker.addGauge("stable_gauge1", "", #none, [150, 200], true);
stableGauge1.update(20);
stableGauge1.update(800);
stableGauge1.update(180);
let stableGauge2 = tracker.addGauge("stable_gauge2", "", #none, [150, 200], true);
stableGauge2.update(20);
stableGauge2.update(800);
stableGauge2.update(180);
let stableCounter1 = tracker.addCounter("stable_counter1", "", true);
stableCounter1.add(5);
let stableCounter2 = tracker.addCounter("stable_counter2", "", true);
stableCounter2.add(7);
let sharedData = tracker.share();
stableGauge1.remove();
stableGauge2.remove();
stableCounter1.remove();
stableCounter2.remove();

let newTracker = PT.PromTrackerTestable("", 5, func() = mockedTime);
// the same gauge, state should be the same
ignore newTracker.addGauge("stable_gauge1", "", #none, [150, 200], true);
// gauge with changed buckets, buckets should be clean
ignore newTracker.addGauge("stable_gauge2", "", #none, [151, 201], true);
// the same counter
ignore newTracker.addCounter("stable_counter1", "", true);
// counter now marked as not stable, should not be unshared
ignore newTracker.addCounter("stable_counter2", "", false);
newTracker.unshare(sharedData);

run(
  test(
    "exposition from unshared tracker",
    newTracker.renderExposition(""),
    M.equals(T.text("stable_gauge1_last{} 180 123006000
stable_gauge1_sum{} 1000 123006000
stable_gauge1_count{} 3 123006000
stable_gauge1_bucket{le=\"150\"} 1 123006000
stable_gauge1_bucket{le=\"200\"} 2 123006000
stable_gauge1_bucket{le=\"+Inf\"} 3 123006000
stable_gauge2_last{} 180 123006000
stable_gauge2_sum{} 1000 123006000
stable_gauge2_count{} 3 123006000
stable_gauge2_bucket{le=\"151\"} 0 123006000
stable_gauge2_bucket{le=\"201\"} 0 123006000
stable_gauge2_bucket{le=\"+Inf\"} 3 123006000
stable_counter1{} 5 123006000
stable_counter2{} 0 123006000\n")),
  )
);
