import Text_ "mo:core/Text";
import PromTracker "../../src/mixins/tracker";
import Http "../../src/Http";
// In production use this instead:
// import PromTracker "mo:promtracker/mixins/tracker";
// import Http "mo:promtracker/Http";

// Example showing how to define `http_request` manually,
// without the `http` mixin.
persistent actor Main {
  include PromTracker(Main);
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

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
