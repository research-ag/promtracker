  import Tracker "../../src/Tracker";
  import { Counter; Gauge } "../../src/lib";

  module Stream {
    public type Stream = {
      tracker : Tracker.Tracker;
      gauge : Tracker.Gauge;
      ctr : Tracker.Counter;
    };
    public func new(tracker : Tracker.Tracker) : Stream = {
      tracker;
      gauge = tracker.newGauge("stream_window_size", [], []);
      ctr = tracker.newCounter("stream_length", []);
    };
    public func set(self : Stream, length : Nat, windowSize : Nat) {
      self.ctr.add(length);
      self.gauge.update(windowSize);
    };
  };
