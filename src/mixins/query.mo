import Prim "mo:prim";
import Types "../internal/Types";

/// Mixin that adds a `pt_query` endpoint returning metrics in structured form.
///
/// Defines:
/// * `public query func pt_query() : async ([Types.Metric], Nat64)`
///
/// Parameters:
/// * `read`: Function that returns the metrics array.
mixin(read : () -> [Types.Metric]) {
  public query func pt_query() : async ([Types.Metric], Nat64) {
   (read(), Prim.time());
  };
};
