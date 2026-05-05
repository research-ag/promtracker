/// Helper functions for Prometheus labels.
///
/// ```motoko name=import
/// import Label "mo:promtracker/Label";
/// ```

import Array "mo:core/Array";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Runtime "mo:core/Runtime";

module {
  /// A label is a key-value pair of strings.
  public type Label = (Text, Text);

  /// Returns `true` if `t` contains only [A-Za-z0-9_].
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

  /// Returns `true` if `name` is a valid Prometheus metric name or label key.
  ///
  /// Valid names match `[a-zA-Z_][a-zA-Z0-9_]*`.
  public func isValidName(name : Text) : Bool {
    let ?first = name.chars().next() else return false;
    if (first >= '0' and first <= '9') return false;
    if (not isAllowedAscii(name)) return false;
    return true;
  };

  /// Escape characters in label values according to Prometheus requirements.
  ///
  /// Escapes `\`, `"`, and `\n`.
  func escape(c : Char) : Text {
    switch (c) {
      case '\\' { return "\\\\" };
      case '\"' { return "\\\"" };
      case '\n' { return "\\n" };
      case _ { return Text.fromChar(c) };
    };
  };

  /// Escapes the entire text `t` for use as a label value.
  public func escapeLabelValue(t : Text) : Text = t.flatMap(escape);

  /// Concatenate two rendered label strings with a comma.
  public func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  /// Render a single label as `key="escaped value"`.
  ///
  /// Traps if `key` is not a valid Prometheus name.
  public func renderLabel(key : Text, value : Text) : Text {
    assert isValidName(key);
    key # "=\"" # escapeLabelValue(value) # "\"";
  };

  /// Render an array of labels as a single comma-separated string.
  public func renderLabels(labels : [Label]) : Text {
    Array.foldLeft(
      labels,
      "",
      func(t, (k, v)) = concat(t, renderLabel(k, v)),
    );
  };

  /// Create a `canister="id"` label from an actor.
  ///
  /// The `id` is the first 5 characters of the canister principal.
  /// Traps if principal cannot be split.
  public func canisterLabel(a : actor {}) : Label {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Runtime.trap("invalid principal");
    return ("canister", name);
  };
};
