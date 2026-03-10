import List "mo:core/pure/List";
import Metrics "Metrics";
import Label "Label";

module {
  // Type passthrough
  public type Counter = Metrics.Counter.Counter;
  public type Gauge = Metrics.Gauge.Gauge;
  public type Heatmap = Metrics.Heatmap.Heatmap;

  // Value variant type
  type TValue = {
    #counter : Metrics.Counter.Counter;
    #gauge : Metrics.Gauge.Gauge;
    #heatmap : Metrics.Heatmap.Heatmap;
    #tracker : Tracker;
  };

  // Static tracker type
  public type Tracker = {
    var labels : Text;
    var values : List.List<TValue>;
    env : { var holdDownPeriod : Nat64 };
    var nonce : Nat;
    id : Nat;
  };

  public func addLabel(self : Tracker, key : Text, value : Text) {
    self.labels := Label.concat(self.labels, Label.renderLabel(key, value));
  };
  private func add(self : Tracker, val : TValue) {
    self.values := self.values.pushFront(val);
  };
  public func newCounter(self : Tracker, name : Text, labels : [Label.Label]) : Metrics.Counter.Counter {
    let labelStr = Label.renderLabels(labels);
    let newCounter = Metrics.Counter.new(name, labelStr, self.nonce);
    self.nonce += 1;
    self.add(#counter newCounter);
    newCounter;
  };
  public func newGauge(self : Tracker, prefix : Text, labels : [Label.Label], limits : [Nat]) : Metrics.Gauge.Gauge {
    let labelStr = Label.renderLabels(labels);
    let newGauge = Metrics.Gauge.new(prefix, labelStr, self.env, limits, self.nonce);
    self.nonce += 1;
    self.add(#gauge newGauge);
    newGauge;
  };
  public func newHeatmap(self : Tracker, prefix : Text, labels : [Label.Label]) : Metrics.Heatmap.Heatmap {
    let labelStr = Label.renderLabels(labels);
    let newHeatmap = Metrics.Heatmap.new(prefix, labelStr, self.nonce);
    self.nonce += 1;
    self.add(#heatmap newHeatmap);
    newHeatmap;
  };
  public func newTracker(self : Tracker, labels : [Label.Label]) : Tracker {
    let labelStr = Label.renderLabels(labels);
    let newTracker : Tracker = {
      var labels = labelStr;
      var values = List.empty();
      env = self.env;
      var nonce = 0;
      id = self.nonce;
    };
    self.nonce += 1;
    self.add(#tracker newTracker);
    newTracker;
  };
  public func removeValue(self : Tracker, value : { id : Nat }) {
    self.values := self.values.filter(
      func(v) = switch v {
        case (#counter c) { c.id != value.id };
        case (#gauge g) { g.id != value.id };
        case (#heatmap h) { h.id != value.id };
        case (#tracker t) { t.id != value.id };
      }
    );
  };
};
