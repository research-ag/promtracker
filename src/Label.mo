import Array "mo:core/Array";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Runtime "mo:core/Runtime";

module {
  public type Label = (Text, Text);

  /// Validate that a Text contains only [A-Za-z0-9_]
  public func isAllowedAscii(t : Text) : Bool {
    for (c in t.chars()) {
      if (
        not (
          (c >= '0' and c <= '9') // 0-9
          or (c >= 'A' and c <= 'Z') // A-Z
          or (c >= 'a' and c <= 'z') // a-z
          or (c == '_') // _
        )
      ) return false;
    };
    true;
  };

  /// Validate metric names and label keys
  public func isValidName(name : Text) : Bool {
    let ?first = name.chars().next() else return false;
    if (first >= '0' and first <= '9') return false;
    if (not isAllowedAscii(name)) return false;
    return true;
  };

  /// Escape single characters in label values according to Prometheus exposition format requirements
  func escape(c : Char) : Text {
    switch (c) {
      case '\\' { return "\\\\" };
      case '\"' { return "\\\"" };
      case '\n' { return "\\n" };
      case _ { return Text.fromChar(c) };
    };
  };

  /// Escape label values according to Prometheus exposition format requirements
  public func escapeLabelValue(t : Text) : Text = t.flatMap(escape);

  /// Concatenate two label strings, handling empty cases
  public func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  /// Render a single label as key="escaped value"
  public func renderLabel(key : Text, value : Text) : Text {
    assert isValidName(key);
    key # "=\"" # escapeLabelValue(value) # "\"";
  };

  /// Render a list of labels as a single label string
  public func renderLabels(labels : [Label]) : Text {
    Array.foldLeft(
      labels,
      "",
      func(t, (k, v)) = concat(t, renderLabel(k, v)),
    );
  };

  /// Create the caniser="id" label witht the short form canister id of an actor
  public func canisterLabel(a : actor {}) : Label {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Runtime.trap("");
    return ("canister", name);
  };
};
