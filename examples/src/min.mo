// Problems with the old PromTracker:
//
// - Persistency
//   - inconsistent behaviour between PullValues and all others
//   - PullValues cannot be persisted because they are functions
//   - other values are "reloaded" after upgrade and identified by prefix and labels
//   - that is not robust
// - Hard to link from inside packages (e.g. stream) to the PromTracker
// - Requires preupgrade/postupgrade which are not desired with EOP

// Arguments for the new Tracker:
// 
// - If PullValues cannot be persisted then why persist the others in the Tracker?
// - Consistent approach: 
//   - Tracker does not persist anything at all
//   - Values are static records, user persists them or not with let and transient let declarations
//   - Values need to be re-registered with Tracker after upgrade
//   - Same value can be registered multiple times with the Tracker, resulting in multiple lines
// - Values can be grouped (bundled) with common labels
//   - Useful for example in streams when each stream tracks a set of values
//   - They can be bundled with a common label for the stream id
//   - Useful for example in DailyBid when each trading pair tracks a set of values
//   - They can be bundles with a common label for the base token
// - Watermarks don't render before they get their first value

// This is a minimal implementation showing the use of the Tracker in this new approach.
// Things not yet implemented for simplicity:
//
// - histograms in Gauges
// - value type Heatmap
// - value type PullValue except the system metrics
// 
// Features removed for now for simplicity: (can be re-introduced later):
// - adding labels with key-value interface, using raw strings for now
// - editing single labels (less use for it because of bundling and common labels)
// - providing custom time function for testing, hardcoding Prim.time for now
// - enabling/disabling watermark in Gauges, both are always enabled now
// - removal (deregistration) of values from Tracker
//   (needed less because we can remove by upgrading and not re-registering)

// We need to import Metrics only if we want to use the pre-defined pull values
// such as system metrics or if we want to bundle multiple values under a common
// label
import Metrics "../../src/Metrics";

// Here we import all value types that we want to use.
// Dot notation only works if we import them individually.
import { Counter; Gauge } "../../src/Metrics";

// This import is required
import PT "../../src/lib";

// This mixin is recommended 
import Http "../../src/mixins/http";

persistent actor Main {
  // This declaration must be transient because Tracker is a class
  // All values must be re-added after upgrade.
  transient let pt = PT.Tracker();

  // Always include the mixin
  include Http(pt.renderExposition, "/metrics");

  // Add a label via key-value pair
  // pt.addLabel("env", "prod");

  // Set whole label string as raw Text
  // pt.setLabels("env=\"prod\"");

  // Add the standard canister="abg45" label
  pt.addCanisterLabel(Main);

  // Add some pre-defined pull values to the Tracker
  pt.addMany([
    Metrics.cyclesBalanceMetric,
    Metrics.canisterVersionMetric,
  ]);

  // Add all system metrics (use as alternative to the previous addMany)
  // pt.add(Metrics.allSystemMetrics);

  // Define some Counters
  let ctr1 = Counter.new("counter", "id=\"1\"");
  let ctr2 = Counter.new("counter", "id=\"2\"");
  
  // Add the counters to the Tracker
  pt.addMany([ctr1.value(), ctr2.value()]);

  // Define the environment for Gauges, consisting of the hold down period.
  // We set it here to 62 seconds.
  // The idea is to have a common environment for all gauges because the hold down period
  // should match the scraping interval of the external scraper.
  let env = Gauge.env(62);

  // Define some Gauges, pass in the common environment
  let gauge1 = Gauge.new("gauge", "id=\"1\"", env);
  let gauge2 = Gauge.new("gauge", "id=\"2\"", env);

  // Add the gauges to the Tracker
  pt.addMany([gauge1.value(), gauge2.value()]);

  // Alternative: Bundle with a common label before adding to the Tracker
  // pt.add(Metrics.bundle("streamid=\"1\"", [ctr1.metrics(), gauge1.metrics()]));
  // pt.add(Metrics.bundle("streamid=\"2\"", [ctr1.metrics(), gauge2.metrics()]));

  // Update counter values on install/upgrade
  ctr1.add(1);
  ctr2.add(2);

  // Set gauge values 
  public func set(x : Nat, y : Nat) {
    gauge1.update(x);
    gauge2.update(y);
  };

  // Change hold down period for all gauges
  // Useful if the scraping interval of the external scraper changes
  public func setHoldDown(x : Nat) {
    env.setHoldDown(x);
  };
};
