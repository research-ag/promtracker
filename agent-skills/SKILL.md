---
name: promtracker
description: Guidelines for integrating and using promtracker for Prometheus metrics in Motoko canisters.
---

# Skill: Promtracker Integration

This skill provides guidelines for agents to integrate and use `promtracker` in Motoko canisters on the Internet Computer.

## Core Concepts

- **Tracker (Optional)**: A persistent hierarchical container for stateful metrics. Required for counters, gauges, and heatmaps that must survive upgrades.
- **Renderer**: A transient object used to collect and render metrics into Prometheus format. Can be used standalone if only pull-based metrics (like system metrics) are needed.
- **Metric Types**: Counter, Gauge, Heatmap, and custom Pull Values.
- **Mixins**: Modular actor components to expose metrics (HTTP, Candid) or add features (Uptime).

## Installation and Setup

### 1. Import Promtracker and Mixins

```motoko
import PT "mo:promtracker";
// Import only the modules you actually use to enable dot-notation
import { Counter; Tracker } "mo:promtracker";
import Http "mo:promtracker/mixins/http"; // For simple setup
import Http_ "mo:promtracker/Http"; // For custom manual setup

```

Importing `Counter`, `Gauge`, `Heatmap`, `Tracker` explicitly enables dot-notation like `ctr.add(1)` instead of `PT.Counter.add(ctr, 1)`. **Only import the modules that are actually used in your code.**

### 2. Initialize Renderer (and optionally Tracker)

The `Renderer` is always required to collect and render metrics. The `Tracker` is only needed if you want to use counters, gauges, or heatmaps that persist across upgrades.

#### Option A: Pull Metrics Only (Minimal Setup)

Use this if you only need system metrics or custom pull values. No `Tracker` is required.

```motoko
persistent actor Main {
  // Renderer is transient and re-initialized on upgrade
  transient let renderer = PT.Renderer();

  // Expose metrics via HTTP
  include Http(renderer.renderExposition, "/metrics");

  // Initialize renderer with pull values
  renderer.addValue(PT.allSystemMetrics);
  renderer.addCanisterLabel(Main);
};

```

#### Option B: Full Setup (with Tracker)

Use this if you need stateful metrics (Counters, Gauges, Heatmaps). The `Tracker` should be persistent.

```motoko
persistent actor Main {
  // Tracker is persistent to maintain metric values across upgrades
  let pt = Tracker.new();

  // Renderer is transient and re-initialized on upgrade
  transient let renderer = PT.Renderer();

  // Expose metrics via HTTP
  include Http(renderer.renderExposition, "/metrics");

  // Initialize renderer
  renderer.addValue(pt.toValue());
  renderer.addValue(PT.allSystemMetrics);
  renderer.addCanisterLabel(Main);
};

```

### 3. Using Other Mixins

In addition to HTTP exposition, `promtracker` provides other mixins:

#### Candid Query Mixin

Allows other canisters to query metrics using Candid via `pt_query()`.

```motoko
import Query "mo:promtracker/mixins/query";
// inside actor

include Query(renderer.read);

```

#### Uptime Mixin

Provides an `uptime` function that returns the number of seconds since the canister was started/upgraded.

```motoko
import Uptime "mo:promtracker/mixins/uptime";
// inside actor

include Uptime();
renderer.addValue(PT.newValue("uptime_seconds", [], uptime));

```

### 4. Custom HTTP Endpoints

If you need to serve other custom routes alongside `/metrics`, you must implement `http_request` manually instead of using the `Http` mixin.

```motoko
import PT "mo:promtracker";
import Http "mo:promtracker/Http";

persistent actor Main {
  transient let renderer = PT.Renderer();

  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    switch (req.method, path) {
      case ("GET", "/metrics") {
        // Use renderer.renderExposition() for Prometheus metrics
        Http.renderPlainText(renderer.renderExposition());
      };
      case ("GET", "/hello") {
        Http.renderPlainText("Hello, world!");
      };
      case (_) Http.render400();
    };
  };

  // Initialize renderer as usual
  renderer.addValue(PT.allSystemMetrics);
};

```

## Adding Metrics

### System Metrics

Add pre-defined system and RTS metrics to the renderer.

```motoko
renderer.addValue(PT.allSystemMetrics);
// Or specific ones:
renderer.addValue(PT.cyclesBalanceMetric);
renderer.addValue(PT.canisterVersionMetric);

```

### Counters

Use counters for values that only increase.

```motoko
let requestCounter = pt.newCounter("requests_total", [("method", "GET")]);
requestCounter.add(1);

```

### Gauges

Use gauges for values that can go up and down. Gauges in `promtracker` support watermarks (min/max/average over a period).

```motoko
// Gauge with limits for watermarks (optional)
let memoryGauge = pt.newGauge("memory_usage_bytes", [], [1024, 1024 * 1024]);
memoryGauge.update(500000);

```

### Heatmaps

Use heatmaps to track distribution of values (e.g., latencies) using power-of-2 buckets.

```motoko
let latencyHeatmap = pt.newHeatmap("request_latency_seconds", []);
latencyHeatmap.add(120); // Adds value to corresponding bucket

```

### Custom Pull Values

Use pull values to dynamically read a value when metrics are requested.

```motoko
renderer.addValue(PT.newValue("custom_metric", [], func() = 42));

```

## Best Practices

1. **Labels**: Use labels to differentiate dimensions of the same metric instead of creating many metrics with different names. Traps if label names are invalid.
2. **Transient Renderer**: Always use a `transient` variable for the `Renderer` and initialize it in the actor body (or constructor).
3. **Optional Tracker**: Use a `Tracker` only if you need stateful metrics like counters or gauges. For simple system metric monitoring, the `Renderer` alone is sufficient.
4. **Use Mixins**: Prefer using provided mixins (e.g., `mo:promtracker/mixins/http`) for simple cases. If you need multiple custom HTTP routes, implement `http_request` manually using `renderer.renderExposition()`.
5. **Hierarchy**: Use `pt.newTracker([("subsystem", "api")])` to create nested trackers for better organization.
6. **Exposition Format**: Prometheus expects metrics to be served as plain text. The `Http` mixin and `Http.renderPlainText` helper handle this automatically.
7. **Selective Imports**: For dot-notation, only import the specific metric modules (`Counter`, `Gauge`, `Heatmap`, `Tracker`) that you actually use.
