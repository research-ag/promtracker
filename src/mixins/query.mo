/// Mixin that adds a `pt_query` endpoint returning metrics in candid form.
///
/// This is for consumption by other canisters.
///
/// Arguments:
///
/// * `read`: Function that returns the metrics to be returned at the `pt_query` endpoint
///
/// ```motoko name=import
/// // This mixin is typically used within an actor
/// ```

import Prim "mo:prim";
import Types "../internal/Types";

mixin (read : () -> [Types.Metric]) {
  /// Returns the current metrics and the current IC time.
  public query func pt_query() : async ([Types.Metric], Nat64) {
    (read(), Prim.time());
  };
};
