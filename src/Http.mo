import Text_ "mo:core/Text";

module TinyHttp {
  /// Http Request type (argument)
  public type Request = {
    method : Text;
    url : Text;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// Http Response type
  public type Response = {
    status_code : Nat16;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// Create a 400 response
  public func render400() : Response = {
    status_code = 400;
    headers : [(Text, Text)] = [];
    body : Blob = "Invalid request";
  };

  /// Create a plain text response
  public func renderPlainText(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "text/plain")];
    body = text.encodeUtf8();
  };
};
