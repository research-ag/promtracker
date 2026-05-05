/// Internal types for PromTracker.
///
/// These types are subject to change and should not be used directly by end users.

import Types "mo:core/Types";

module {
  /// A single metric line: (name, labels, value).
  public type Metric = (Text, Text, Nat);

  /// Counter state.
  public type Counter = {
    parent : Tracker;
    name : Text;
    labels : Text;
    var value : Int;
    id : Nat;
  };

  /// Environment for watermarks.
  public type Environment = {
    var holdDownPeriod : Nat64; // in nanoseconds
  };

  /// Watermark state.
  public type Watermark = {
    var activated : Bool; // a watermark is activated after the first update
    var mark : Nat;
    var lastMarkTime : Nat64;
    env : Environment;
  };

  /// Gauge state.
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

  /// Heatmap state.
  public type Heatmap = {
    parent : Tracker;
    prefix : Text;
    labels : Text;
    var count : Int;
    var sum : Int;
    var buckets : [var Int];
    id : Nat;
  };

  /// Variant of trackable values.
  public type TValue = {
    #counter : Counter;
    #gauge : Gauge;
    #heatmap : Heatmap;
    #tracker : Tracker;
  };

  /// Tracker state.
  public type Tracker = {
    parent : ?Tracker;
    var labels : Text;
    var values : Types.Pure.List<TValue>;
    env : Environment;
    var nonce : Nat;
    id : Nat;
  };
};
