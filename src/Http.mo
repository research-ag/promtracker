/// Minimal HTTP types and helpers for Prometheus exposition.
///
/// ```motoko name=import
/// import Http "mo:promtracker/Http";
/// ```

import Text_ "mo:core/Text";

module TinyHttp {
  /// HTTP Request type.
  public type Request = {
    method : Text;
    url : Text;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// HTTP Response type.
  public type Response = {
    status_code : Nat16;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// Create a 400 Bad Request response.
  public func render400() : Response = {
    status_code = 400;
    headers : [(Text, Text)] = [];
    body : Blob = "Invalid request";
  };

  /// Create a 200 OK plain text response.
  public func renderPlainText(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "text/plain")];
    body = text.encodeUtf8();
  };

  /// Create a 200 OK JSON response.
  public func renderJson(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "application/json; charset=utf-8")];
    body = text.encodeUtf8();
  };

  /// Create a 200 OK YAML response.
  public func renderYaml(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "application/yaml; charset=utf-8")];
    body = text.encodeUtf8();
  };
};
