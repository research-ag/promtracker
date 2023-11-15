import PT "../src/lib";

import Suite "mo:matchers/Suite";
import T "mo:matchers/Testable";
import M "mo:matchers/Matchers";

let { run; test; suite } = Suite;

var tracker = PT.PromTracker(0);
tracker.now := func() = 123000000000000;

/* --------------------------------------- */
let testValue = tracker.addPullValue("test_val_0", func() = 150);
run(
  test(
    "pull value output",
    tracker.renderExposition(),
    M.equals(T.text("test_val_0{} 150 123000000\n")),
  )
);

/* --------------------------------------- */
testValue.remove();
run(
  test(
    "value removed",
    tracker.renderExposition(),
    M.equals(T.text("")),
  )
);

/* --------------------------------------- */
let counter = tracker.addCounter("test_counter", false);
run(
  test(
    "initial counter state",
    tracker.renderExposition(),
    M.equals(T.text("test_counter{} 0 123000000\n")),
  )
);
counter.add(3);
run(
  test(
    "counter state",
    tracker.renderExposition(),
    M.equals(T.text("test_counter{} 3 123000000\n")),
  )
);
counter.add(4);
run(
  test(
    "counter state",
    tracker.renderExposition(),
    M.equals(T.text("test_counter{} 7 123000000\n")),
  )
);
counter.set(2);
run(
  test(
    "counter state",
    tracker.renderExposition(),
    M.equals(T.text("test_counter{} 2 123000000\n")),
  )
);
counter.remove();

/* --------------------------------------- */
let gauge = tracker.addGauge("test_gauge", null, false);
run(
  test(
    "initial gauge state",
    tracker.renderExposition(),
    M.equals(T.text("test_gauge_sum{} 0 123000000
test_gauge_count{} 0 123000000
test_gauge_high_watermark{} 0 123000000
test_gauge_low_watermark{} 0 123000000\n")),
  )
);

gauge.update(200);
gauge.update(250);
gauge.update(230);
gauge.update(280);
gauge.update(120);
gauge.update(160);

run(
  test(
    "gauge state",
    tracker.renderExposition(),
    M.equals(T.text("test_gauge_sum{} 1240 123000000
test_gauge_count{} 6 123000000
test_gauge_high_watermark{} 280 123000000
test_gauge_low_watermark{} 120 123000000\n")),
  )
);

gauge.remove();

/* --------------------------------------- */
let gaugeWithBuckets = tracker.addGauge("buckets_gauge", ?[10, 20, 50, 120, 180], false);
run(
  test(
    "initial gauge state",
    tracker.renderExposition(),
    M.equals(T.text("buckets_gauge_sum{} 0 123000000
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
    tracker.renderExposition(),
    M.equals(T.text("buckets_gauge_sum{} 1000301 123000000
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
let gaugeWithBucketsOutOfOrder = tracker.addGauge("buckets_gauge", ?[50, 10, 160, 30], false);
gaugeWithBucketsOutOfOrder.update(10);
gaugeWithBucketsOutOfOrder.update(900);
gaugeWithBucketsOutOfOrder.update(25);
gaugeWithBucketsOutOfOrder.update(65);

run(
  test(
    "gauge state",
    tracker.renderExposition(),
    M.equals(T.text("buckets_gauge_sum{} 1000 123000000
buckets_gauge_count{} 4 123000000
buckets_gauge_high_watermark{} 900 123000000
buckets_gauge_low_watermark{} 10 123000000
buckets_gauge_bucket{le=\"10\"} 1 123000000
buckets_gauge_bucket{le=\"30\"} 2 123000000
buckets_gauge_bucket{le=\"50\"} 2 123000000
buckets_gauge_bucket{le=\"160\"} 3 123000000
buckets_gauge_bucket{le=\"+Inf\"} 4 123000000\n")),
  )
);

gaugeWithBucketsOutOfOrder.remove();
