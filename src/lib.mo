import Array_ "mo:core/Array";
import List "mo:core/pure/List";
import Nat_ "mo:core/Nat";
import Nat64_ "mo:core/Nat64";
import Principal "mo:core/Principal";
import Text_ "mo:core/Text";
import Prim "mo:prim";
import Metrics "Metrics";

module {
  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  public class Tracker() = {
    // Global labels
    var globalLabels = "";

    public func setLabels(labels : Text) { globalLabels := labels };
    public func addLabel(key : Text, value : Text) {
      globalLabels := concat(globalLabels, key # "=\"" # value # "\"");
    };
    public func addCanisterLabel(a : actor {}) {
      let s = Principal.fromActor(a).toText();
      let ?name = s.split(#char '-').next() else Prim.trap("");
      addLabel("canister", name);
    };

    // Values
    var values = List.empty<Metrics.Value>();

    public func add(set : Metrics.Value) {
        values := values.pushFront(set);
    };

    public func addMany(sets : [Metrics.Value]) {
      for (set in sets.vals()) {
        values := values.pushFront(set);
      };
    };

    /// Read all current metrics as a structured array
    public func read() : [Metrics.Metric] {
      values.map(func(v) = v.read()).reverse().toArray().flatten();
    };

    private func renderMetric(m : Metrics.Metric, globalLabels : Text, time : Text) : Text {
      let (metricName, metricLabels, natValue) = m;
      metricName # "{" # concat(globalLabels, metricLabels) # "} "
      # natValue.toText() # " " # time # "\n";
    };

    /// Render all current metrics to prometheus exposition format
    public func renderExposition() : Text {
      let timeStr = (Prim.time() / 1_000_000).toText();
      read().map(
        func(m) = renderMetric(m, globalLabels, timeStr)
      ).vals().join("");
    };
  };

};
