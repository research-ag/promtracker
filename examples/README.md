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

Two canisters get deployed called `simple` and `persistency`.
Their canister ids will get printed.

You can watch the metrics from a browser at a URL like this:
http://txyno-ch777-77776-aaaaq-cai.raw.localhost:8000/metrics
where `txyno-ch777-77776-aaaaq-cai` is replaced by the canister id
that is shown during `icp deploy`.
Refresh the page to see how the metrics have changed in the meantime.

## Simple

The simple example shows how to configure a PromTracker,
how to add a PullValue and a Gauge,
how provide the http endpoint.

The metrics in the browser will look like this:
```
time_last{canister="tz2ag"} 159 1770294366163
time_sum{canister="tz2ag"} 4150 1770294366163
time_count{canister="tz2ag"} 29 1770294366163
time_high_watermark{canister="tz2ag"} 164 1770294366163
time_low_watermark{canister="tz2ag"} 119 1770294366163
time_bucket{canister="tz2ag",le="500"} 29 1770294366163
time_bucket{canister="tz2ag",le="600"} 29 1770294366163
time_bucket{canister="tz2ag",le="700"} 29 1770294366163
time_bucket{canister="tz2ag",le="800"} 29 1770294366163
time_bucket{canister="tz2ag",le="900"} 29 1770294366163
time_bucket{canister="tz2ag",le="1000"} 29 1770294366163
time_bucket{canister="tz2ag",le="1100"} 29 1770294366163
time_bucket{canister="tz2ag",le="1200"} 29 1770294366163
time_bucket{canister="tz2ag",le="1300"} 29 1770294366163
time_bucket{canister="tz2ag",le="1400"} 29 1770294366163
time_bucket{canister="tz2ag",le="1500"} 29 1770294366163
time_bucket{canister="tz2ag",le="1600"} 29 1770294366163
time_bucket{canister="tz2ag",le="+Inf"} 29 1770294366163
cycles{canister="tz2ag"} 1069400377267 1770294366163
instructions_last{canister="tz2ag"} 7573 1770294366163
instructions_sum{canister="tz2ag"} 28603 1770294366163
instructions_count{canister="tz2ag"} 4 1770294366163
instructions_high_watermark{canister="tz2ag"} 7708 1770294366163
instructions_low_watermark{canister="tz2ag"} 6661 1770294366163
instructions_bucket{canister="tz2ag",le="4800"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="5000"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="5200"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="5400"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="5600"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="5800"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="6000"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="6200"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="6400"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="6600"} 0 1770294366163
instructions_bucket{canister="tz2ag",le="+Inf"} 4 1770294366163
bytes_last{canister="tz2ag"} 50 1770294366163
bytes_sum{canister="tz2ag"} 152 1770294366163
bytes_count{canister="tz2ag"} 4 1770294366163
bytes_high_watermark{canister="tz2ag"} 50 1770294366163
bytes_low_watermark{canister="tz2ag"} 26 1770294366163
bytes_bucket{canister="tz2ag",le="10"} 0 1770294366163
bytes_bucket{canister="tz2ag",le="20"} 0 1770294366163
bytes_bucket{canister="tz2ag",le="30"} 2 1770294366163
bytes_bucket{canister="tz2ag",le="40"} 2 1770294366163
bytes_bucket{canister="tz2ag",le="50"} 4 1770294366163
bytes_bucket{canister="tz2ag",le="60"} 4 1770294366163
bytes_bucket{canister="tz2ag",le="70"} 4 1770294366163
bytes_bucket{canister="tz2ag",le="80"} 4 1770294366163
bytes_bucket{canister="tz2ag",le="90"} 4 1770294366163
bytes_bucket{canister="tz2ag",le="100"} 4 1770294366163
bytes_bucket{canister="tz2ag",le="+Inf"} 4 1770294366163
```

## Persistency

The persistency example show additionally how to make the metrics persist across canister upgrades.
This can be configured selectively, on a per-metric basis.

While you watch the metrics re-run this command:
```sh
icp deploy
```
This will upgrade both canisters.
You can see in the browser how the metrics of the simple examples have been reset.
In the persistency example you will see that some metrics reset
and some didn't,
just as they were configured to do.
