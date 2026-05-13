/// Minimal HTTP types and response helpers.
///
/// This module defines basic `Request` and `Response` types compatible with
/// the IC's HTTP gateway, and provides helpers for rendering common responses.
///
/// ```motoko name=import
/// import Http "mo:promtracker/Http";
/// ```

import Text_ "mo:core/Text";

module TinyHttp {
  /// An HTTP request.
  public type Request = {
    /// HTTP method (e.g., "GET", "POST").
    method : Text;
    /// Request URL.
    url : Text;
    /// List of HTTP headers.
    headers : [(Text, Text)];
    /// Request body.
    body : Blob;
  };

  /// An HTTP response.
  public type Response = {
    /// HTTP status code (e.g., 200, 404).
    status_code : Nat16;
    /// List of HTTP headers.
    headers : [(Text, Text)];
    /// Response body.
    body : Blob;
  };

  /// Returns a `400 Bad Request` response.
  public func render400() : Response = {
    status_code = 400;
    headers : [(Text, Text)] = [];
    body : Blob = "Invalid request";
  };

  /// Returns a `200 OK` response with `text/plain` content type.
  public func renderPlainText(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "text/plain")];
    body = text.encodeUtf8();
  };
  /// Returns a `200 OK` response with `application/json` content type.
  public func renderJson(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "application/json; charset=utf-8")];
    body = text.encodeUtf8();
  };
  /// Returns a `200 OK` response with `application/yaml` content type.
  public func renderYaml(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "application/yaml; charset=utf-8")];
    body = text.encodeUtf8();
  };
};
