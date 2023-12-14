import PT "../src/lib";

import Suite "mo:motoko-matchers/Suite";
import T "mo:motoko-matchers/Testable";
import M "mo:motoko-matchers/Matchers";

let { run; test; suite } = Suite;

var mockedTime : Nat64 = 123_000_000_000_000;
var tracker = PT.PromTrackerTestable("", 5, func() = mockedTime);
//PT.now := func() = mockedTime;

/* --------------------------------------- */
let testValue = tracker.addPullValue("test_val_0", func() = 150);
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
let counter = tracker.addCounter("test_counter", false);
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
let gauge = tracker.addGauge("test_gauge", []);
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
let gaugeWithBuckets = tracker.addGauge("buckets_gauge", [10, 20, 50, 120, 180]);
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
let gauge2 = tracker.addGauge("buckets_gauge", []);
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
