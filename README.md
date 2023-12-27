[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/promtracker)](https://mops.one/promtracker)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/promtracker)](https://mops.one/promtracker/docs)

# Motoko value tracker for prometheus

## Overview

The purpose of PromTracker is to record different kinds of values during the operation of a canister,
aggregate them and in some case process them, 
and export them in the Prometheus exposition format.

The exposition format can then be provided on an http endpoint from where it can be accessed by a scraper.
Serving the http endpoint is not directly part of this package, but is provided in the example directory.

The two main value types that can be tracked are Counters and Gauges. 
These values are explicitly updated by events in canister code.

A counter is normally an ever-increasing counter such as the number of total requests received. The scraper only sees it's last value. The values between scraping events are considered not important. 

A gauge is a more frequently changing and normally fluctuating value such as the size of the last request, time between last two events, etc. The values between scraping events are considered important. That's why a gauge value allows to automatically track the high and low watermark between scraping events as well as a histogram. The exported histograms over time can be used to create heatmaps.

The third value type is the PullValue which is stateless version of a counter. 
It is not explicitly updated by events in canister code.
Instead, the value is calculated on the fly when the scraping happens. 
This type is convenient to expose a canister's system state such a cycle balance and memory size because those are already tracked by the runtime or management canister and canister code does not need to update them explicitly.
This type can also be used to expose an expression in one or more other tracked values regardless of those values' types such as for example the sum of two other values.

The tracker class PromTracker is instantiated once per canister.
Then various code modules can each register a value with the PromTracker class that they like to have tracked
and that they the maintain (i.e. update).
The http endpoint accesses only the PromTracker instance once to get the exposition of all tracked values.

## Links

The package is published on [MOPS](https://mops.one/promtracker) and [GitHub](https://github.com/research-ag/promtracker).

The API documentation can be found [here](https://mops.one/promtracker/docs/lib) on Mops.

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

## Examples

### Canister including http endpoint

Our [example canister](examples)
tracks the "heartrate" by tracking the time in milliseconds between subsequent heartbeats.
This value is a GaugeValue and it allows us to see the high and low watermarks as well as the distribution in the form of a histogram.

### The PromTracker class
Create tracker instance like this:
```motoko
let tracker = PT.PromTracker(65);
```
65 seconds is the recommended interval if prometheus pulls stats with interval 60 seconds. This value used to clear high 
and low watermarks in gauge values, so each highest and lowest value during your canister lifecycle will
be reflected in the prometheus data.

Add some values:
```motoko
let successfulHeartbeats = tracker.addCounter("successful_heartbeats", true);
let failedHeartbeats = tracker.addCounter("failed_heartbeats", true);
let heartbeats = tracker.addPullValue("heartbeats", func() = successfulHeartbeats.value() + failedHeartbeats.value());
let heartbeatDuration = tracker.addGauge("heartbeat_duration", null);
```

Update values:
```motoko
successfulHeartbeats.add(2);
failedHeartbeats.add(1);
heartbeatDuration.update(10);
heartbeatDuration.update(18);
heartbeatDuration.update(14);
```

Get prometheus exposition:
```motoko
let text : Text = tracker.renderStats();
```

Make stats surviving canister upgrades:
```motoko
stable var statsData : PT.StableData = null;

system func preupgrade() {
  statsData := tracker.share();
};

system func postupgrade() {
  tracker.unshare(statsData);
};
  
```

### PullValue
A stateless value interface, which runs the provided getter function on demand.
```motoko
let storageSize = tracker.addPullValue("storage_size", func() = storage.size());
```

### CounterValue
An accumulating counter value interface. Second argument is a flag whether you want to save the state of this value
to stable data using share/unshare api
```motoko
    let requestsAmount = tracker.addCounter("requests_amount", false);
    // now it will output 0
    requestsAmount.add(3);
    // it will output 3
    requestsAmount.add(1);
    // now it will output 4
    requestsAmount.set(0);
    // now it will output 0 again
```

### GaugeValue
A gauge value interface for ever-changing value, with ability to catch the highest and lowest value during interval, 
set on tracker instance and ability to bucket the values for histogram output. Outputs few stats at once: sum of all 
pushed values, amount of pushes, lowest value during interval, highest value during interval, histogram buckets. 
Second argument accepts edge values for buckets
```motoko
    let requestDuration = tracker.addGauge("request_duration", ?[50, 110]);
    requestDuration.update(123);
    requestDuration.update(101);
    // now it will output stats: 
    // request_duration_sum: 224
    // request_duration_count: 2
    // request_duration_high_watermark: 123
    // request_duration_low_watermark: 101
    // request_duration_low_watermark: 101
    // request_duration_bucket{le="50"}: 0
    // request_duration_bucket{le="110"}: 1
    // request_duration_bucket{le="+Inf"} 2
```

### System metrics
PromTracker has the ability to extend your prometheus exposition output with these pull values:
1) `cycles_balance` // Cycles.balance()
1) `rts_memory_size` // Prim.rts_memory_size()
1) `rts_heap_size` // Prim.rts_heap_size()
1) `rts_total_allocation` // Prim.rts_total_allocation()
1) `rts_reclaimed` // Prim.rts_reclaimed()
1) `rts_max_live_size` // Prim.rts_max_live_size()
1) `rts_max_stack_size` // Prim.rts_max_stack_size()
1) `rts_callback_table_count` // Prim.rts_callback_table_count()
1) `rts_callback_table_size` // Prim.rts_callback_table_size()
1) `rts_mutator_instructions` // Prim.rts_mutator_instructions()
1) `rts_collector_instructions` // Prim.rts_collector_instructions()
1) `stablememory_size` // StableMemory.size()

To register them, call function:
```motoko
metrics.addSystemValues();
```

## Copyright

MR Research AG, 2023

## Authors

Andy Gura (AndyGura) with contributions from Timo Hanke (timohanke)

## License

Apache-2.0
