// Like min.mo but without PullValues
// If PullValues aren't needed then we can get away without the Renderer

// This import is required
// will be "mo:promtracker/Tracker"
import PT "../../src/Tracker";

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
  // Required 2 lines:
  //  - create static Tracker (must be declared stable)
  //  - include mixin
  let pt = PT.new();
  include Http(pt.renderFunction(), "/metrics");

  // Re-define the canister label (just for the hyptothetical case that it has changed)
  // This assumes that the canister label is the only global labels because setLabels overwrites the global labels.
  // Other global labels have to be re-added after this line.
  pt.setLabels([PT.canisterLabel(Main), ("example", "no-pull")]);

  // Optional:
  // Set the watermark hold down period if different from the default value of 302.
  // The default is chosen for a 5 min scraping interval.
  // Can be dynamically changed later without upgrade if needed.
  // Note: We could pass this in Pt.new(62), but prefer to keep PT.new() without arguments
  // because it is easier for users who go with the default.
  // Note: This function will re-run after upgrade but that's ok because it overwrites the setting.
  pt.setHoldDown(62);

  // Alternative:
  // This can save some lines of code.
  // The [] can be replaced with initial (Counter, Gauge) values.
  // let pt = PT.newWith(PT.canisterLabel(Main), [], 62);

  // Define some Counters and Gauges
  // Declaration must be stable (not transient)
  let ctr1 = pt.newCounter("counter", [("id", "1")]);
  let ctr2 = pt.newCounter("counter", [("id", "2")]);
  let gauge1 = pt.newGauge("gauge", [("id", "1")], []);
  let gauge2 = pt.newGauge("gauge", [("id", "2")], []);

  // Demo code follows

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
    gauges := gauges.concat([pt.newGauge(name, labels, [])]);
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
      gauge = tracker.newGauge("stream_window_size", [], []);
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
