import Types "mo:core/Types";

module {
  public type Metric = (Text, Text, Nat);

  public type Counter = {
    parent : Tracker;
    name : Text;
    labels : Text;
    var value : Int;
    id : Nat;
  };
  public type Environment = {
    var holdDownPeriod : Nat64; // in nanoseconds
  };
  public type Watermark = {
    var activated : Bool; // a watermark is activated after the first update
    var mark : Nat;
    var lastMarkTime : Nat64;
    env : Environment;
  };
  public type Gauge = {
    parent : Tracker;
    prefix : Text;
    labels : Text;
    var lastValue : Nat;
    var count : Nat;
    var sum : Nat;
    high : Watermark;
    low : Watermark;
    limits : [Nat];
    counters : [var Nat];
    id : Nat;
  };
  public type Heatmap = {
    parent : Tracker;
    prefix : Text;
    labels : Text;
    var count : Int;
    var sum : Int;
    var buckets : [var Int];
    id : Nat;
  };
  public type TValue = {
    #counter : Counter;
    #gauge : Gauge;
    #heatmap : Heatmap;
    #tracker : Tracker;
  };
  public type Tracker = {
    parent : ?Tracker;
    var labels : Text;
    var values : Types.Pure.List<TValue>;
    env : Environment;
    var nonce : Nat;
    id : Nat;
  };
};
