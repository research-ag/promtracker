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
  /// `method`: HTTP method (e.g., "GET", "POST").
  /// `url`: Request URL.
  /// `headers`: List of HTTP headers.
  /// `body`: Request body.
  public type Request = {
    method : Text;
    url : Text;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// An HTTP response.
  /// `status_code`: HTTP status code (e.g., 200, 404).
  /// `headers`: List of HTTP headers.
  /// `body`: Response body.
  public type Response = {
    status_code : Nat16;
    headers : [(Text, Text)];
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
