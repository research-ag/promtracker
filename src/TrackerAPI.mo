import List "mo:core/pure/List";
import Metrics "Metrics";
import Label "Label";
import Types "internal/Types";

module {
  // Type passthrough
  public type Counter = Types.Counter;
  public type Gauge = Types.Gauge;
  public type Heatmap = Types.Heatmap;
  public type Tracker = Types.Tracker;

  public func addLabel(self : Tracker, key : Text, value : Text) {
    self.labels := Label.concat(self.labels, Label.renderLabel(key, value));
  };
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter {
    let labelStr = Label.renderLabels(labels);
    let newCounter = Metrics.Counter.new(self, name, labelStr, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#counter newCounter);
    newCounter;
  };
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge {
    let labelStr = Label.renderLabels(labels);
    let newGauge = Metrics.Gauge.new(self, prefix, labelStr, self.env, limits, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#gauge newGauge);
    newGauge;
  };
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap {
    let labelStr = Label.renderLabels(labels);
    let newHeatmap = Metrics.Heatmap.new(self, prefix, labelStr, self.nonce);
    self.nonce += 1;
    self.values := self.values.pushFront(#heatmap newHeatmap);
    newHeatmap;
  };
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker {
    let labelStr = Label.renderLabels(labels);
    let newTracker : Tracker = {
      parent = ?self;
      var labels = labelStr;
      var values = List.empty();
      env = self.env;
      var nonce = 0;
      id = self.nonce;
    };
    self.nonce += 1;
    self.values := self.values.pushFront(#tracker newTracker);
    newTracker;
  };
  public func unregister(self : Tracker) {
    let ?parent = self.parent else return;
    parent.values := parent.values.filter(
      func(v) = switch v {
        case (#tracker t) { t.id != self.id };
        case (_) true;
      }
    );
  };
};
