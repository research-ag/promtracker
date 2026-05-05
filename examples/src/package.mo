import Http "../../src/mixins/http";
import { Tracker } "../../src/lib";
import  Stream "../src/mock-stream";
import Array "mo:core/Array";
import Nat_ "mo:core/Nat";

persistent actor Main {
  let pt = Tracker.new();
  include Http(pt.renderFunction(), "/metrics");
  pt.setLabels([Tracker.canisterLabel(Main)]);
  pt.setHoldDown(62);
  
  public func setHoldDown(seconds : Nat) {
    pt.setHoldDown(seconds);
  };

  // Demonstrate how to use "sub-trackers"
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
    // Important: unregister the stream's sub-tracker from the parent tracker
    // This removes all of the stream's metrics at once
    streams[i].tracker.unregister();
    // Now remove the stream from the array
    streams := Array.tabulate<Stream.Stream>(
      streams.size() - 1,
      func(j) = if (j < i) streams[j] else streams[j + 1],
    );
  };
};
