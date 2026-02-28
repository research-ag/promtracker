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
  transient let openapiYaml : Text = "openapi: 3.1.0\ninfo:\n  title: metrics\n  version: \"1\"\npaths:\n  " # route # ":\n    get:\n      responses:\n        \"200\":\n          description: Metrics\n          content:\n            text/plain:\n              schema:\n                type: string\n";
  transient let openapiJson : Text = "{\"openapi\":\"3.1.0\",\"info\":{\"title\":\"metrics\",\"version\":\"1\"},\"paths\":{\"" # route # "\":{\"get\":{\"responses\":{\"200\":{\"description\":\"Metrics\",\"content\":{\"text/plain\":{\"schema\":{\"type\":\"string\"}}}}}}}}}";
  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = req.url.split(#char '?').next() else return Http.render400();
    if (req.method != "GET") return Http.render400();
    if (path == route) {
      return Http.renderPlainText(text());
    } else if (path == "/openapi.yaml") {
      return Http.renderYaml(openapiYaml);
    } else if (path == "/openapi.json") {
      return Http.renderJson(openapiJson);
    } else {
      return Http.render400();
    };
  };
};

/*
openapi: 3.1.0
info:
  title: metrics
  version: "1"
paths:
  /metrics:
    get:
      responses:
        "200":
          description: Metrics
          content:
            text/plain:
              schema:
                type: string
*/
