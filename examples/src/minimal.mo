import Http "../../src/mixins/http";
import PromTracker "../../src/mixins/base";
// In production:
// import Http "mo:promtracker/mixins/http";
// import PromTracker "mo:promtracker/mixins/base";

/// A minimal canister exposing various system values as Prometheus system metrics.
/// Values include cycle balance, canister state nonce ("version"), memory size, heap size, etc.
///
/// Note: This example works without defining `preupgrade`, `postupgrade` system functions
/// because all system values are pulled on-demand, hence don't require persisting.
persistent actor Main {
  include PromTracker(Main, true);
  include Http(pt);
};
