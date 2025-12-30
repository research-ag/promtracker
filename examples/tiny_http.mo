import Text "mo:core/Text";

module TinyHttp {
  public type Request = {
    method : Text;
    url : Text;
    headers : [(Text, Text)];
    body : Blob;
  };

  public type Response = {
    status_code : Nat16;
    headers : [(Text, Text)];
    body : Blob;
  };

  public func render400() : Response = {
    status_code : Nat16 = 400;
    headers : [(Text, Text)] = [];
    body : Blob = "Invalid request";
  };

  public func renderPlainText(text : Text) : Response = {
    status_code = 200;
    headers = [("content-type", "text/plain")];
    body = text.encodeUtf8();
  };
};
