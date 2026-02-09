import Text_ "mo:core/Text";
import Http "../Http";
import PT "../";

/// Mixin that adds Prometheus `/metrics` endpoint
/// Defines:
/// 
/// * public query func http_request(req : Http.Request) : async Http.Response
///
/// Arguments:
///
/// * pt: PromTracker class from which to generate the exposition
mixin(pt : PT.PromTracker, route : Text) {
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    switch (req.method, path) {
      case ("GET", route) {
        Http.renderPlainText(pt.renderExposition());
      };
      case (_) Http.render400();
    };
  };
};
