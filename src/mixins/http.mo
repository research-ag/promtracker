import Text_ "mo:core/Text";
import Http "../Http";

/// Mixin that adds a `/metrics` endpoint returning text
/// Defines:
///
/// * public query func http_request(req : Http.Request) : async Http.Response
///
/// Arguments:
///
/// * text: Function that returns the text to be returned at the `/metrics` endpoint
mixin(text : () -> Text, route : Text) {
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    switch (req.method, path) {
      case ("GET", route) {
        Http.renderPlainText(text());
      };
      case (_) Http.render400();
    };
  };
};
