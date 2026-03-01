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

// This import is needed only in the files that _use_ the values,
// i.e. that call for example `gauge.update(..)` or `Gauge.update(gauge, ..)`.
// This may not be needed in the top-level actor file.
// will be "mo:promtracker"
import { Counter; Gauge } "../../src/lib";

// Optional: only used in this particular demo code
import Array "mo:core/Array";
import Nat_ "mo:core/Nat";

// Example on how to remove a top-level value from the Tracker via migration.
// Using this migration function will cause `ctr2` to be "reset" during an upgrade
// because the initialization expression in `let ctr2 = ...` will be re-executed.
// Alternatively, we can drop `let ctr2` from the top-level actor code with this expression.
//   
// import { removeCtr2 } "migration";
// (with migration = removeCtr2)

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
  let ctr1 = pt.newCounter("counter", [("id","1")]);
  let ctr2 = pt.newCounter("counter", [("id","2")]);
  let gauge1 = pt.newGauge("gauge", [("id","1")]);
  let gauge2 = pt.newGauge("gauge", [("id","2")]);

  // Add some pre-defined pull values to the Renderer
  renderer.addPullValues([
    PT.cyclesBalanceMetric,
    PT.canisterVersionMetric,
  ]);

  // Add all system metrics (use as alternative to the previous addPullValues)
  // renderer.addPullValue(PT.allSystemMetrics);

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
    gauges := gauges.concat([pt.newGauge(name, labels)]);
  };

  // Demonstrate how to use "sub-trackers"
  // Mock Stream package
  module Stream {
    public type Stream = {
      tracker : PT.Tracker;
      gauge : PT.Gauge;
      ctr : PT.Counter;
    };
    public func new(tracker : PT.Tracker) : Stream = {
      tracker;
      gauge = tracker.newGauge("stream_window_size", []);
      ctr = tracker.newCounter("stream_length", []);
    };
    public func set(self : Stream, length : Nat, windowSize : Nat) {
      self.ctr.add(length);
      self.gauge.update(windowSize);
    };
  };

  // Stream manager
  var streams : [Stream.Stream] = [];
  public func newStream() {
    let id = streams.size();
    // create a sub-tracker for the new stream
    let subPt = pt.newTracker([("streamid", id.toText())]);
    // create and add the new stream, pass down sub-tracker
    streams := streams.concat([Stream.new(subPt)]);
  };
  public func updateStream(i : Nat, length : Nat, windowSize : Nat) {
    streams[i].set(length, windowSize);
  };
  public func removeStream(i : Nat) {
    // Important: remove the stream's sub-tracker from the parent tracker
    // This removes all of the stream's metrics at once
    pt.removeValue(streams[i].tracker);
    // Now remove the stream from the array
    streams := Array.tabulate<Stream.Stream>(
      streams.size() - 1,
      func(j) = if (j < i) streams[j] else streams[j + 1],
    );
  };
};
