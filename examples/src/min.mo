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
//
// Open problems with the new Tracker:
// - how do we remove values?
//   - user code can drop the values with a migration function but they will remain in the Tracker
//   - this will keep the corresponding metric lines in the exposition with their last values
//   - their value can no longer be updated

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
// - removal (deregistration) of values from Tracker

// This import is required
// will be "mo:promtracker"
import PT "../../src/lib";

// This mixin is recommended
// will be "mo:promtracker/mixins/http"
import Http "../../src/mixins/http";

// This import is needed only in the files that _use_ the values,
// i.e. that call for example `gauge.update(..)` or `Gauge.update(gauge, ..)`.
// This may not be needed in the top-level actor file.
// will be "mo:promtracker"
import { Counter; Gauge } "../../src/lib";

// Optional: only used in this particular demo code
import Array_ "mo:core/Array";

persistent actor Main {
  // Required 3 lines:
  //  - create static Tracker (must be declared stable)
  //  - create Renderer class (must be declared transient)
  //  - include mixin
  let pt = PT.new();
  transient let renderer = PT.Renderer(pt);
  include Http(renderer.renderExposition, "/metrics");

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
  let ctr1 = pt.newCounter("counter", "id=\"1\"");
  let ctr2 = pt.newCounter("counter", "id=\"2\"");
  let gauge1 = pt.newGauge("gauge", "id=\"1\"");
  let gauge2 = pt.newGauge("gauge", "id=\"2\"");

  // Add some pre-defined pull values to the Renderer
  renderer.addPullValues([
    PT.cyclesBalanceMetric,
    PT.canisterVersionMetric,
  ]);

  // Add all system metrics (use as alternative to the previous addPullValues)
  // renderer.addPullValue(PT.allSystemMetrics);

  // Add other global labels to the Renderer via key-value pair if desired
  // Can be dynamically added later without upgrade if needed
  // renderer.addLabel("env", "prod");

  // Set (overwrite) the Renderer's whole label string as raw Text if desired
  // Can be dynamically set later without upgrade if needed
  // renderer.setLabels("env=\"prod\"");

  // Demo code follow

  // Increment counters
  ctr1.add(1);
  ctr2.add(2);
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
  public func addGauge(name : Text) {
    gauges := gauges.concat([pt.newGauge(name, "")]);
  };
};
