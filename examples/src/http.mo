import Text_ "mo:core/Text";
import Http "../../src/Http";
import PromTracker "../../src/mixins/base";
// In production use this instead:
// import Http "mo:promtracker/Http";
// import PromTracker "mo:promtracker/mixins/base";

// The `base` mixin does not define the public http_request function
// so that we can define it ourselves.
// For that purpose the mixin puts the `Http` module in scope.

persistent actor Main {
  include PromTracker(Main, false);
  system func preupgrade() { pt_preupgrade() };
  system func postupgrade() { pt_postupgrade() };

  transient let counter = pt.addCounter("counter", "", true);

  system func heartbeat() : async () { counter.add(1) };

  // Expose the `/metrics` endpoint
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    switch (req.method, path) {
      case ("GET", "/metrics") {
        Http.renderPlainText(pt.renderExposition(""));
      };
      case ("GET", "/hello") {
        Http.renderPlainText("Hello, world!");
      };
      case (_) Http.render400();
    };
  };
};
