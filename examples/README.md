# Run

Requirements:

* You need `mops` installed
* You need a local `dfx` running in the background

Run:

```
dfx deploy
```

The output should look like this:

```
Deploying all canisters.
Creating canisters...
Creating canister heartrate...
heartrate canister created with canister id: asrmz-lmaaa-aaaaa-qaaeq-cai
Building canisters...
Installing canisters...
Creating UI canister on the local network.
The UI canister on the "local" network is "a3shf-5eaaa-aaaaa-qaafa-cai"
Installing code for canister heartrate, with canister ID asrmz-lmaaa-aaaaa-qaaeq-cai
Deployed canisters.
URLs:
  Backend canister via Candid interface:
    heartrate: http://127.0.0.1:4943/?canisterId=a3shf-5eaaa-aaaaa-qaafa-cai&id=asrmz-lmaaa-aaaaa-qaaeq-cai
```

Copy the canister id (in the example above `asrmz-lmaaa-aaaaa-qaaeq-cai`) and 
point the browser to `http://asrmz-lmaaa-aaaaa-qaaeq-cai.localhost:4943/metrics` 

The output will look like this:
```
time_sum{} 19590 1700221913679
time_count{} 30 1700221913679
time_high_watermark{} 692 1700221913679
time_low_watermark{} 631 1700221913679
time_bucket{le="500"} 0 1700221913679
time_bucket{le="600"} 0 1700221913679
time_bucket{le="700"} 30 1700221913679
time_bucket{le="800"} 30 1700221913679
time_bucket{le="900"} 30 1700221913679
time_bucket{le="1000"} 30 1700221913679
time_bucket{le="1100"} 30 1700221913679
time_bucket{le="1200"} 30 1700221913679
time_bucket{le="1300"} 30 1700221913679
time_bucket{le="1400"} 30 1700221913679
time_bucket{le="+Inf"} 30 1700221913679
```

For deployment on mainnet run:

```
dfx deploy --network ic
```

and point the browser to `https://<canister id>.raw.icp0.io/metrics`.
The output will look like this:

```
time_sum{} 149683 1700222126127
time_count{} 160 1700222126127
time_high_watermark{} 2119 1700222126127
time_low_watermark{} 669 1700222126127
time_bucket{le="500"} 0 1700222126127
time_bucket{le="600"} 0 1700222126127
time_bucket{le="700"} 7 1700222126127
time_bucket{le="800"} 20 1700222126127
time_bucket{le="900"} 76 1700222126127
time_bucket{le="1000"} 127 1700222126127
time_bucket{le="1100"} 149 1700222126127
time_bucket{le="1200"} 155 1700222126127
time_bucket{le="1300"} 156 1700222126127
time_bucket{le="1400"} 156 1700222126127
time_bucket{le="+Inf"} 160 1700222126127
```
