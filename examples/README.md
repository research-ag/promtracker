# Executable examples to run locally
## Run

Install `icp` executable:
```sh
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/dfinity/icp-cli/releases/download/v0.1.0-beta.6/icp-cli-installer.sh | sh
```

Install [node](https://nodejs.org/) (LTS recommended) including `npm`.
Required for `mops`.

Install `mops`:
```sh
npm install -g ic-mops
mops toolchain init
```

Change into the examples subdirectory:
```sh
cd examples
```

Then do:
```sh
icp network start -d
icp deploy
icp network stop
```

The example canisters will get deployed and their canister ids will be printed.

You can watch the metrics from a browser at a URL like this:
http://txyno-ch777-77776-aaaaq-cai.raw.localhost:8000/metrics
where `txyno-ch777-77776-aaaaq-cai` is replaced by the canister id
that is shown during `icp deploy`.
Refresh the page to see how the metrics have changed since then.

## Minimal

Uses `mixin/base, mixin/http`.

Demonstrates a minimal setup to expose only default system metrics.
Very useful already for minimal health monitoring which every canister in production should have.
It requires only one code line.

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

## Main

Uses `mixin/base, mixin/http`.

Demonstrates the use of the three main metric types `PullValue`, `CounterValue` and `GaugeValue`.
In the case of Gauges it shows how to define buckets so that the Gauge can produce a heatmap in Grafana.

It also shows how to persist Counter and Gauge across canister upgrades.

Metrics render like this:
```text
cycles{canister="tz2ag"} 1453739534899 1770400540297
heartbeats{canister="tz2ag",is_stable="false"} 120 1770400540297
heartbeats{canister="tz2ag",is_stable="true"} 120 1770400540297
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

## Advanced

Uses `mixin/base, mixin/http`.

Focuses on Gauges and shows advanced usage of them
to track:

* amount of instructions used by other update calls
* size of call arguments delivered to other update calls

The metrics render like this:
```text
instructions_last{canister="tc74d"} 7573 1770400881392
instructions_sum{canister="tc74d"} 297487 1770400881392
instructions_count{canister="tc74d"} 38 1770400881392
instructions_high_watermark{canister="tc74d"} 9453 1770400881392
instructions_low_watermark{canister="tc74d"} 6312 1770400881392
instructions_bucket{canister="tc74d",le="6000"} 0 1770400881392
instructions_bucket{canister="tc74d",le="7000"} 6 1770400881392
instructions_bucket{canister="tc74d",le="8000"} 20 1770400881392
instructions_bucket{canister="tc74d",le="9000"} 33 1770400881392
instructions_bucket{canister="tc74d",le="10000"} 38 1770400881392
instructions_bucket{canister="tc74d",le="+Inf"} 38 1770400881392
bytes_last{canister="tc74d"} 50 1770400881392
bytes_sum{canister="tc74d"} 2036 1770400881392
bytes_count{canister="tc74d"} 38 1770400881392
bytes_high_watermark{canister="tc74d"} 90 1770400881392
bytes_low_watermark{canister="tc74d"} 18 1770400881392
bytes_bucket{canister="tc74d",le="10"} 0 1770400881392
bytes_bucket{canister="tc74d",le="20"} 2 1770400881392
bytes_bucket{canister="tc74d",le="30"} 5 1770400881392
bytes_bucket{canister="tc74d",le="40"} 10 1770400881392
bytes_bucket{canister="tc74d",le="50"} 19 1770400881392
bytes_bucket{canister="tc74d",le="60"} 25 1770400881392
bytes_bucket{canister="tc74d",le="70"} 29 1770400881392
bytes_bucket{canister="tc74d",le="80"} 33 1770400881392
bytes_bucket{canister="tc74d",le="90"} 38 1770400881392
bytes_bucket{canister="tc74d",le="100"} 38 1770400881392
bytes_bucket{canister="tc74d",le="+Inf"} 38 1770400881392
```

## Heatmap

Uses `mixin/base, mixin/http`.

Demonstrates the `Heatmap` metric type which is similar to a Gauge but has automated (exponential) bucket creation built in.

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

## Http

Uses `mixin/base`.

The `http` mixin assumes that the prometheus endpoint `/metrics` is the only route that the canister serves.

This example shows how to use promtracker if the canister wants to simultaneously serve other routes from other parts of the canister code.
It shows how to define the custom `http_request` handler with other routes added.

The metrics render like this:
```text
counter{canister="tm5rl"} 6056 1770401117142
```
and another `/hello` route is served.

## Plain

Uses `mixin/http`.

Shows how to define `PromTracker` without the `base` mixin,
including manual sharing of stable state across upgrades.

The metrics render like this:
```text
counter{canister="tf62x"} 6321 1770401156396
```
