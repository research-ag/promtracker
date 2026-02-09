import Text_ "mo:core/Text";

import Http "../../src/Http";
import PT "../../src";
// In production use this instead:
// import Http "mo:promtracker/Http";
// import PT "mo:promtracker";

// This example shows how to use PromTracker in plain mode, without mixins.
persistent actor Main {
  transient let pt = PT.PromTracker(PT.canisterLabel(Main), 65);
  var ptStableData : PT.StableData = null;
  system func preupgrade() { ptStableData := pt.share() };
  system func postupgrade() { pt.unshare(ptStableData) };

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };

  // Expose the `/metrics` endpoint
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    switch (req.method, path) {
      case ("GET", "/metrics") {
        Http.renderPlainText(pt.renderExposition());
      };
      case ("GET", "/hello") {
        Http.renderPlainText("Hello, world!");
      };
      case (_) Http.render400();
    };
  };
};
