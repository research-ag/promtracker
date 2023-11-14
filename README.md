# Motoko value tracker for prometheus

## Overview

A value tracker, designed specifically to use as source for Prometheus.
It contains functionality to register/deregister various kinds of custom values on the fly, 
built-in system stats of your canister, and statistics output as `Text` in prometheus exposition format

## Links

The package is published on [MOPS](https://mops.one/promtracker) and [GitHub](https://github.com/research-ag/promtracker).
Please refer to the README on GitHub where it renders properly with formulas and tables.

The API documentation can be found [here](https://mops.one/promtracker/docs/lib) on Mops.

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

## Examples

Look at our [example canister](examples/example_canister.mo)

Create tracker instance like this:
```motoko
let tracker = PT.PromTracker(65);
```
65 seconds is the recommended interval if prometheus pulls stats with interval 60 seconds. This value used to clear high 
and low watermarks in [gauge values](#gauge-value), so each highest and lowest value during your canister lifecycle will
be reflected in prometheus graphs

Add some values:
```motoko
let successfulHeartbeats = tracker.addCounter("successful_heartbeats", true);
let failedHeartbeats = tracker.addCounter("failed_heartbeats", true);
let heartbeats = tracker.addPullValue("heartbeats", func() = successfulHeartbeats.value() + failedHeartbeats.value());
let heartbeatDuration = tracker.addGauge("heartbeat_duration", true);
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

## Value types

### Pull value
A stateless value interface, which runs the provided getter function on demand.
```motoko
let storageSize = tracker.addPullValue("storage_size", func() = storage.size());
```

### Counter value
An accumulating counter value interface. Second argument is a flag whether you want to save this value
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

### Gauge value
A gauge value interface for ever-changing value, with ability to catch the highest and lowest value during interval, 
set on tracker instance. Outputs 4 stats at once: sum of all pushed values, amount of pushes, lowest value during 
interval, highest value during interval.
```motoko
    let requestDuration = tracker.addGauge("request_duration", true);
    requestDuration.update(123);
    requestDuration.update(101);
    // now it will output stats: 
    // request_duration_sum: 224
    // request_duration_count: 2
    // request_duration_high_watermark: 123
    // request_duration_low_watermark: 101
```

## Canister system stats
PromTracker has the ability to extend your prometheus exposition output with these [pull values](#pull-value):
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

Andy Gura with contributions from Timo Hanke.

## License

Apache-2.0
