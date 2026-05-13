/// Internal type definitions.
///
/// These types are used internally by the library and are not intended
/// to be used directly by end users.
///
/// ```motoko name=import
/// import Types "mo:promtracker/internal/Types";
/// ```

import Types "mo:core/Types";

module {
  /// A single metric sample: `(name, labels, value)`.
  public type Metric = (Text, Text, Nat);

  /// State for a `Counter`.
  public type Counter = {
    parent : Tracker;
    name : Text;
    labels : Text;
    var value : Int;
    id : Nat; // unique ID for unregistering, drawn from parent's nonce
  };
  /// Configuration for the metric environment.
  public type Environment = {
    var holdDownPeriod : Nat64; // in nanoseconds
  };
  /// State for a watermark in a `Gauge`.
  public type Watermark = {
    var activated : Bool; // a watermark is activated after the first update
    var mark : Nat;
    var lastMarkTime : Nat64;
    env : Environment;
  };
  /// State for a `Gauge`.
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
    id : Nat; // unique ID for unregistering, drawn from parent's nonce
  };
  /// State for a `Heatmap`.
  public type Heatmap = {
    parent : Tracker;
    prefix : Text;
    labels : Text;
    var count : Int;
    var sum : Int;
    var buckets : [var Int];
    id : Nat; // unique ID for unregistering, drawn from parent's nonce
  };
  /// Internal variant for values held by a `Tracker`.
  public type TValue = {
    #counter : Counter;
    #gauge : Gauge;
    #heatmap : Heatmap;
    #tracker : Tracker;
  };
  /// State for a `Tracker`.
  ///
  /// Each Tracker has a mutable `nonce` used to generate unique `id` values
  /// assigned to its children (Counter, Gauge, Heatmap, or nested Tracker).
  /// These `id`s are stable keys used only for unregistering.
  public type Tracker = {
    parent : ?Tracker;
    var labels : Text;
    var values : Types.Pure.List<TValue>;
    env : Environment;
    var nonce : Nat; // source of unique IDs for children
    id : Nat; // unique ID for unregistering, drawn from parent's nonce
  };
};
