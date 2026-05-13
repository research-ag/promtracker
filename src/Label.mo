/// Validation and rendering of Prometheus labels.
///
/// This module provides helpers for validating metric names and label keys,
/// escaping label values, and rendering labels into the Prometheus exposition format.
///
/// ```motoko name=import
/// import Label "mo:promtracker/Label";
/// ```

import Array "mo:core/Array";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Runtime "mo:core/Runtime";

module {
  /// A key-value pair representing a Prometheus label.
  public type Label = (Text, Text);

  /// Returns `true` if `t` contains only characters allowed in metric names and label keys.
  ///
  /// Allowed characters are `[A-Za-z0-9_]`.
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
  /// A valid name must:
  /// - contain only characters allowed by `isAllowedAscii`,
  /// - not start with a digit.
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

  /// Escapes label values according to Prometheus exposition format requirements.
  ///
  /// The following characters are escaped:
  /// - `\` -> `\\`
  /// - `"` -> `\"`
  /// - `\n` -> `\n`
  public func escapeLabelValue(t : Text) : Text = t.flatMap(escape);

  /// Concatenates two comma-separated label strings.
  ///
  /// Handles empty strings gracefully, ensuring no leading or trailing commas.
  public func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  /// Renders a single label as a `key="value"` string.
  ///
  /// Traps if `key` is not a valid Prometheus label name (see `isValidName`).
  public func renderLabel(key : Text, value : Text) : Text {
    assert isValidName(key);
    key # "=\"" # escapeLabelValue(value) # "\"";
  };

  /// Renders a list of labels as a single comma-separated string.
  ///
  /// Traps if any label key in `labels` is not a valid Prometheus label name.
  public func renderLabels(labels : [Label]) : Text {
    Array.foldLeft(
      labels,
      "",
      func(t, (k, v)) = concat(t, renderLabel(k, v)),
    );
  };

  /// Returns a `canister="id"` label for the given actor.
  ///
  /// Currently extracts the first component of the canister principal's text representation.
  ///
  /// Traps if the canister ID cannot be extracted.
  public func canisterLabel(a : actor {}) : Label {
    let s = Principal.fromActor(a).toText();
    let ?name = s.split(#char '-').next() else Runtime.trap("");
    return ("canister", name);
  };
};
