import T "../../src/TrackerAPI";
import { Counter; Gauge } "../../src/lib";

module Stream {
  public type Stream = {
    tracker : T.Tracker;
    gauge : T.Gauge;
    ctr : T.Counter;
  };
  public func new(tracker : T.Tracker) : Stream = {
    tracker;
    gauge = tracker.newGauge("stream_window_size", [], []);
    ctr = tracker.newCounter("stream_length", []);
  };
  public func set(self : Stream, length : Nat, windowSize : Nat) {
    self.ctr.add(length);
    self.gauge.update(windowSize);
  };
};
