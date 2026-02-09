[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/promtracker)](https://mops.one/promtracker)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/promtracker)](https://mops.one/promtracker/docs)

# Motoko value tracker for prometheus

## Overview

`PromTracker` is a `mixin` which adds Prometheus metrics to your canisters.
By including the mixin,
the canister exports real-time metrics in the Prometheus exposition format at the HTTP route `/metrics`.
From the endpoint the metrics can be scraped by a Prometheus scraper.

The list of exported metrics is initially empty.
The canister has to register the values it wants to export with the tracker.
Here, a _value_ corresponds to a single metric which results in one line in the exported exposition format.
Registration of values is a one-time action
and is most commonly done in the top-level actor code,
i.e. during canister installation.
However, it is also possible to register values dynamically at a later time.

The canister code then updates the registered values at runtime
during the specific event that corresponds to the value. 
The two main such value types are `CounterValue` and `GaugeValue`. 

A `CounterValue` is normally an ever-increasing counter such as the number of total requests received. The scraper only sees its last value. The values between scraping events are not visible.

A `GaugeValue` captures a frequently changing, fluctuating value such as the size of the last request, time between last two events, etc.
The values of interest occur _between_ the scraping events (not at the scraping event). 
A gauge value automatically tracks the high and low watermarks between scraping events plus a histogram in which all values are captured.
The histogram can be used to create heatmaps in Grafana.

There is another value type which is not explicitly updated by canister code, the `PullValue`.
The value is calculated on the fly ("pulled") when the `/metrics` endpoint is being scraped.
Any state that is accessible to query functions can be used in the calculation.

For example, the canister's system state such as cycle balance and memory size can be exposed through `PullValue`s.
They are already tracked by the canister's runtime or by the management canister.
The canister does not need to update them through "events" like it does
for `Counter` and `Gauge` values.
A `PullValue` means they are read at scraping time and returned.

`Counter` and `Gauge` values can be persisted across canister upgrades.
Whether a value's data should persist can be configured on a per-value basis. 

## Links

The package is published on [MOPS](https://mops.one/promtracker) and [GitHub](https://github.com/research-ag/promtracker).

The API documentation can be found [here](https://mops.one/promtracker/docs/lib) on Mops.

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

## Usage

### Executable examples 

The `examples/` directory contains executable examples.
For instructions how to run them see: [examples/README.md](examples/README.md).

### Minimal code

The minimal code to use `promtracker` is:

```motoko
import PromTracker "mo:promtracker/mixins/tracker";
import Http "mo:promtracker/mixins/http";

persistent actor Main {
  include PromTracker(Main);
  include Http(pt, "/metrics");
  pt.addSystemValues();
};
```

The `pt.addSystemValues()` command registers
a default set of system metrics including cycle balance
and memory stats. 
Without this command the metrics would be empty without further code.
The default system metrics are all `PullValue`s.

Metrics render like this:
```text
cycles_balance{canister="tl4x7"} 1497180100444 1770400321653
canister_version{canister="tl4x7"} 2 1770400321653
rts_memory_size{canister="tl4x7"} 5308416 1770400321653
rts_heap_size{canister="tl4x7"} 5274976 1770400321653
rts_total_allocation{canister="tl4x7"} 5275208 1770400321653
rts_reclaimed{canister="tl4x7"} 0 1770400321653
rts_max_live_size{canister="tl4x7"} 0 1770400321653
rts_max_stack_size{canister="tl4x7"} 4194304 1770400321653
rts_callback_table_count{canister="tl4x7"} 0 1770400321653
rts_callback_table_size{canister="tl4x7"} 0 1770400321653
rts_mutator_instructions{canister="tl4x7"} 0 1770400321653
rts_collector_instructions{canister="tl4x7"} 0 1770400321653
rts_upgrade_instructions{canister="tl4x7"} 7320 1770400321653
rts_stable_memory_size{canister="tl4x7"} 0 1770400321653
rts_logical_stable_memory_size{canister="tl4x7"} 0 1770400321653
```

### PullValue

A `PullValue` is added like this:

```motoko
import Cycles "mo:core/Cycles";

transient let _cycleBalance = pt.addPullValue("cycles", "", Cycles.balance);
```
and will render as:

```text
cycles{canister="tz2ag"} 1453739534899 1770400540297
```

Here, `Cycles.balance` can be replaced by any function `() -> Nat` that returns the value.

The `pt : PromTracker` instance is already available because it is created by the `mixin`.

### Labels

All value registration functions have as their first argument the metric name.

The tracker automatically adds the `canister=".."` label to each metric.

Additional per-metric labels can be added with the second argument in the registration function.  
For example, passing `"mylabel1=value1,mylabel2=value2"` instead of `""`
will make the metric render as

```text
cycles{canister="tz2ag",mylabel1="value1",mylabel2="value2"} 1453739534899 1770400540297
```

### Persistence

If we exclusively use `PullValue`s
then we don't need `preupgrade`, `postupgrade` system functions.
This was the case in the minimal example.

For any other type of values we need to add:
```motoko
system func preupgrade() { pt_preupgrade() };
system func postupgrade() { pt_postupgrade() };
```

The `pt_preupgrade, pt_postupgrade` are already defined by the `tracker` mixin.

Arbitrary other code can be freely added to the system function bodies before or after the 
`pt_preupgrade(), pt_postupgrade()` calls.

### CounterValue

A `CounterValue` can be demonstrated by a heartbeat counter.
In this example one heartbeat counter resets on canister upgrade,
the other one persists across upgrades.

```motoko
transient let counter0 = pt.addCounter("heartbeats", "is_stable=\"false\"", false);
transient let counter1 = pt.addCounter("heartbeats", "is_stable=\"true\"", true);

system func heartbeat() : async () {
  counter0.add(1);
  counter1.add(1);
};
```

The metrics render like this:
```text
heartbeats{canister="tz2ag",is_stable="false"} 120 1770400540297
heartbeats{canister="tz2ag",is_stable="true"} 120 1770400540297
```

Alternatively, we could implement a counter ourselves in canister state 
and expose it through a `PullValue` like this:

```motoko
transient var counter0 = 0;
var counter1 = 0;
transient let _ctr = pt.addPullValue("counter", "is_stable=\"false\"", func() = counter0);
transient let _ctr = pt.addPullValue("counter", "is_stable=\"true\"", func() = counter1);
```

### GaugeValue

A `GaugeValue` can be demonstrated by tracking the "heartbeat interval",
i.e. the time between consecutive heartbeats.
This makes for an interesting heatmap in Grafana.

```motoko
import Int "mo:core/Int";
import Util "mo:promtracker";

transient let timeGauge = pt.addGauge("time", "", #both, Util.limits(100, 10, 10), false);

transient var last_time : ?Int = null;
system func heartbeat() : async () {
  let now = Time.now() / 1_000_000;
  switch (last_time) {
    case (?last) timeGauge.update(Int.abs(now - last));
    case (_) {};
  };
  last_time := ?now;
};
```

Here, the heartbeat intervals are measured in milliseconds.
The `GaugeValue` stores the last recorded value
and keeps a high watermark and low watermark.
Watermarks by default get held for 305 seconds
before they can be overwritten by values "under" the mark.
That way, a Grafana agent that scrapes at a 5-minute interval cannot miss a watermark.
It might see the same watermark twice but that is usually not a problem.

The `GaugeValue` also creates a histogram with 10 buckets (plus the +Inf bucket)
where the bucket limits are: 110, 120, 130, .., 200.

The metrics render like this:
```text
time_last{canister="tz2ag"} 180 1770400540297
time_sum{canister="tz2ag"} 18017 1770400540297
time_count{canister="tz2ag"} 119 1770400540297
time_high_watermark{canister="tz2ag"} 220 1770400540297
time_low_watermark{canister="tz2ag"} 126 1770400540297
time_bucket{canister="tz2ag",le="110"} 0 1770400540297
time_bucket{canister="tz2ag",le="120"} 0 1770400540297
time_bucket{canister="tz2ag",le="130"} 3 1770400540297
time_bucket{canister="tz2ag",le="140"} 31 1770400540297
time_bucket{canister="tz2ag",le="150"} 66 1770400540297
time_bucket{canister="tz2ag",le="160"} 94 1770400540297
time_bucket{canister="tz2ag",le="170"} 105 1770400540297
time_bucket{canister="tz2ag",le="180"} 114 1770400540297
time_bucket{canister="tz2ag",le="190"} 116 1770400540297
time_bucket{canister="tz2ag",le="200"} 118 1770400540297
time_bucket{canister="tz2ag",le="+Inf"} 119 1770400540297
```

Grafana can translate these histograms into heatmaps
which display the distribution of values over time.

You can remove the watermarks from the metrics by replacing argument `#both` with 
`#high` (only high watermark),
`#low` (only low watermark) or `#none`. 

### Heatmap

The `Heatmap` is a simplified `GaugeValue`.
It does not have watermarks and does not require the user to 
define buckets.
Instead, it creates exponentially sized buckets automatically on demand.

```motoko
import Int "mo:core/Int";

transient let heatmap = pt.addHeatmap("heatmap", "", false);

transient var last_time : ?Int = null;
system func heartbeat() : async () {
  let now = Time.now() / 1_000_000;
  switch (last_time) {
    case (?last) {
      let v : Nat = Int.abs(now - last);
      heatmap.addEntry(v);
    };
    case (_) {};
  };
  last_time := ?now;
};
```

The metrics render like this:
```text
heatmap{canister="t63gs",le="0"} 0 1770401064297
heatmap{canister="t63gs",le="1"} 0 1770401064297
heatmap{canister="t63gs",le="2"} 0 1770401064297
heatmap{canister="t63gs",le="4"} 0 1770401064297
heatmap{canister="t63gs",le="8"} 0 1770401064297
heatmap{canister="t63gs",le="16"} 0 1770401064297
heatmap{canister="t63gs",le="32"} 0 1770401064297
heatmap{canister="t63gs",le="64"} 0 1770401064297
heatmap{canister="t63gs",le="128"} 197 1770401064297
heatmap{canister="t63gs",le="256"} 5695 1770401064297
heatmap{canister="t63gs",le="512"} 5700 1770401064297
heatmap_count{canister="t63gs"} 5700 1770401064297
heatmap_sum{canister="t63gs"} 865284 1770401064297
```

### Additional HTTP routes

Most backend canisters do not serve HTTP request.
However, if we want to serve routes other than `/metrics` with our own code 
then we need to define the public `http_request` function ourselves.
We import the `http` module for this, not the `http` mixin.

```motoko
import Text_ "mo:core/Text";
import PromTracker "mo:promtracker/mixins/tracker";
import Http "mo:promtracker/Http";

persistent actor Main {
  include PromTracker(Main);

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };

  // Expose the `/metrics` endpoint
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    switch (req.method, path) {
      case ("GET", "/metrics") {
        Http.renderPlainText(pt.renderExposition());
      };
      case ("GET", "/hello") {
        Http.renderPlainText("Hello, world!");
      };
      case (_) Http.render400();
    };
  };
};
```

### Plain mode (without `tracker` mixin)

It is possible to use the `PromTracker` class directly without the `tracker` mixin.
The `http` mixin can still be used for serving the `/metrics` endpoint.

```motoko
import PT "mo:promtracker";
import Http "mo:promtracker/mixins/http";

persistent actor Main {
  transient let pt = PT.PromTracker(PT.canisterLabel(Main));
  include Http(pt, "/metrics");

  var ptStableData : PT.StableData = null;
  system func preupgrade() { ptStableData := pt.share() };
  system func postupgrade() { pt.unshare(ptStableData) };

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };
};
```

In plain mode we get control over the global `canister="..."` label and can modify it or remove it.
We can also change the 305-second interval to reset watermarks:

```motoko
pt.setWatermarkHoldPeriod(65);
```

A value of 65 seconds is recommended for a 1-minute scraping interval.

## Default system metrics

The system metrics consist of the following

* `cycles_balance` // Prim.cyclesBalance()
* `canister_version` // Prim.canisterVersion()
* `rts_memory_size` // Prim.rts_memory_size()
* `rts_heap_size` // Prim.rts_heap_size()
* `rts_total_allocation` // Prim.rts_total_allocation()
* `rts_reclaimed` // Prim.rts_reclaimed()
* `rts_max_live_size` // Prim.rts_max_live_size()
* `rts_max_stack_size` // Prim.rts_max_stack_size()
* `rts_callback_table_count` // Prim.rts_callback_table_count()
* `rts_callback_table_size` // Prim.rts_callback_table_size()
* `rts_mutator_instructions` // Prim.rts_mutator_instructions()
* `rts_collector_instructions` // Prim.rts_collector_instructions()
* `rts_upgrade_instructions` // Prim.rts_upgrade_instructions()
* `rts_stable_memory_size` // Prim.rts_stable_memory_size()
* `rts_logical_stable_memory_size` // Prim.rts_logical_stable_memory_size()

## Copyright

MR Research AG, 2023 - 2026

## Authors

Andy Gura (AndyGura) with contributions from Timo Hanke (timohanke)

## License

Apache-2.0
