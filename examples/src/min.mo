// Problems with the old PromTracker:
//
// - Persistency
//   - inconsistent behaviour between PullValues and all others
//   - PullValues cannot be persisted because they are functions
//   - other values are "reloaded" after upgrade and identified by prefix and labels
//   - that is not robust
// - Hard to link from inside packages (e.g. stream) to the PromTracker
// - Requires preupgrade/postupgrade functions which are not desired with EOP

// Arguments for the new Tracker:
//
// - clear separation between persistent Tracker and transient Renderer (wraps around Tracker)
// - Tracker is static and benefits from EOP
// - Tracker can be passed down into packages from where new values can be registered
//   - registration can happen dynamically, yet the values persist across upgrades
// - the difference between PullValues and other values remains but they are separated cleanly
// - Watermarks don't render before they get their first value

// This is a minimal implementation showing the use of the Tracker in this new approach.
// Things not yet implemented for simplicity:
//
// - histograms in Gauges
// - value type Heatmap
// - value type PullValue except the system metrics (but straight-forward to add next)
//
// Features removed for now for simplicity: (can be re-introduced later):
// - storing labels as a key-value map, using raw Text for now
// - providing custom time function for testing, hardcoding Prim.time for now
// - enabling/disabling watermark in Gauges, both are always enabled now

// This import is required
// will be "mo:promtracker"
import PT "../../src/lib";

// This mixin is recommended
// will be "mo:promtracker/mixins/http"
import Http "../../src/mixins/http";

// This mixin is optional. It exposes metrics in candid form instead of raw Text.
// will be "mo:promtracker/mixins/query"
import Query "../../src/mixins/query";

// This import is needed only in the files that _use_ the values,
// i.e. that call for example `gauge.update(..)` or `Gauge.update(gauge, ..)`.
// This may not be needed in the top-level actor file.
// will be "mo:promtracker"
import { Counter; Gauge; Tracker } "../../src/lib";

// Optional: only used in this particular demo code
import Array_ "mo:core/Array";

// Example on how to remove a top-level value from the Tracker via migration.
// Using this migration function causes `ctr2` to be unregistered from the Tracker
// and removed from memory.
// We can then drop the line `let ctr2` from the top-level actor code.
// If the line stays in place then a new `ctr2` will be created after an upgrade and
// the initialization expression after `=` will be evaluated.
//
// import { removeCtr2 } "migration";
// (with migration = removeCtr2)

persistent actor Main {
  // Required 3 lines:
  //  - create static Tracker (must be declared stable)
  //  - create Renderer class (must be declared transient)
  //  - include mixin
  let pt = Tracker.new();
  transient let renderer = PT.Renderer();
  renderer.addValue(pt.toValue());
  include Http(renderer.renderExposition, "/metrics");
  include Query(renderer.read);

  // Optional:
  // Add the canister="..." label with the canister id short form as value
  // Note: The Renderer keeps its own global labels which it adds to any labels that are kept in the Tracker
  // These labels need to be re-added after upgrade because the Renderer is transient.
  // However, there is no downside to this.
  // This may even be desirable if the canister id changes after an upgrade (e.g. by cloning a canister snapshot to a different id)
  renderer.addCanisterLabel(Main);

  // Optional:
  // Set the watermark hold down period if different from the default value of 302.
  // The default is chosen for a 5 min scraping interval.
  // Can be dynamically changed later without upgrade if needed.
  // Note: We could pass this in Pt.new(62), but prefer to keep PT.new() without arguments
  // because it is easier for users who go with the default.
  // Note: This function will re-run after upgrade but that's ok because it overwrites the setting.
  pt.setHoldDown(62);

  // Define some Counters and Gauges
  // Declaration must be stable (not transient)
  let ctr1 = pt.newCounter("counter", [("id", "1")]);
  let ctr2 = pt.newCounter("counter", [("id", "2")]);
  let gauge1 = pt.newGauge("gauge", [("id", "1")], []);
  let gauge2 = pt.newGauge("gauge", [("id", "2")], []);
  let ctr21 = pt.newCounter("counter", [("id", "1"), ("tracker", "pt2")]);
  let ctr22 = pt.newCounter("counter", [("id", "2"), ("tracker", "pt2")]);

  // Add some pre-defined pull values to the Renderer
  // renderer.addValue(PT.allRtsMetrics);
  // or few at once
  renderer.addValue(
    [
      PT.cyclesBalanceMetric,
      PT.canisterVersionMetric,
    ].bundle([])
  );

  // Add all system metrics (use as alternative to the previous addValues)
  // renderer.addValue(PT.allSystemMetrics);

  // Add some custom pull value
  renderer.addValue(PT.newValue("custom_pull_value", [], func() = 123));
  // or few at once
  renderer.addValue(
    [
      PT.newValue("custom_pull_value", [("index", "0")], func() = 456),
      PT.newValue("custom_pull_value", [("index", "1")], func() = 789),
    ].bundle([])
  );

  // Add other global labels to the Renderer via key-value pair if desired
  // Can be dynamically added later without upgrade if needed
  renderer.addLabel("example", "min");

  // Set (overwrite) the Renderer's whole label string as raw Text if desired
  // Can be dynamically set later without upgrade if needed
  // renderer.setLabels("env=\"prod\"");

  // Demo code follow

  // Increment counters
  ctr1.add(1);
  ctr2.add(2);
  ctr21.add(3);
  ctr22.add(4);
  public func inc() {
    ctr1.add(1);
    ctr2.add(2);
  };

  // Set gauge values
  public func set(x : Nat, y : Nat) {
    gauge1.update(x);
    gauge2.update(y);
  };

  // Dynamically change hold down period for all gauges
  // Use this if the scraping interval of the external scraper changes
  public func setHoldDown(seconds : Nat) {
    pt.setHoldDown(seconds);
  };

  // Demonstrate how to dynamically add values
  // This can happen inside a package but the Tracker (pt) needs to be passed down
  var gauges : [PT.Gauge] = [];
  public func addGauge(name : Text, labels : [(Text, Text)]) {
    gauges := gauges.concat([pt.newGauge(name, labels, [])]);
  };
};
