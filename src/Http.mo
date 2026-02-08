import Text_ "mo:core/Text";

module TinyHttp {
  /// INTERNAL. Do not use directly.
  /// Exported as `HttpReq` in the main module.
  public type Request = {
    method : Text;
    url : Text;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// INTERNAL. Do not use directly.
  /// Exported as `HttpResp` in the main module.
  public type Response = {
    status_code : Nat16;
    headers : [(Text, Text)];
    body : Blob;
  };

  /// INTERNAL. Do not use directly.
  public func render400() : Response = {
    status_code : Nat16 = 400;
    headers : [(Text, Text)] = [];
    body : Blob = "Invalid request";
  };

  /// INTERNAL. Do not use directly.
  public func renderPlainText(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "text/plain")];
    body = text.encodeUtf8();
  };
};
