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
mixin(pt : PT.PromTracker) {
  public query func http_request(req : Http.Request) : async Http.Response {
    pt.http_request(req);
  };
};
