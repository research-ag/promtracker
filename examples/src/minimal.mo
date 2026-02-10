import PromTracker "../../src/mixins/tracker";
import PT_ "../../src/";
import Http "../../src/mixins/http";
// In production:
// import PromTracker "mo:promtracker/mixins/tracker";
// import Http "mo:promtracker/mixins/http";

/// A minimal canister exposing various system values as Prometheus system metrics.
/// Values include cycle balance, canister state nonce ("version"), memory size, heap size, etc.
///
/// Note: This example works without defining `preupgrade`, `postupgrade` system functions
/// because all system values are pulled on-demand, hence don't require persisting.
persistent actor Main {
  include PromTracker(Main);
  include Http(pt, "/metrics");
  pt.addSystemValues();
};
