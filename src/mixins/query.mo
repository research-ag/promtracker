import Prim "mo:prim";
import Types "../internal/Types";

/// Mixin that adds a `pt_query` endpoint returning metrics in candid form.
/// This is for consumption by other canisters.
///
/// Arguments:
///
/// * read: Function that returns the metrics to be returned at the `pt_query` endpoint
mixin (read : () -> [Types.Metric]) {
  public query func pt_query() : async ([Types.Metric], Nat64) {
    (read(), Prim.time());
  };
};
