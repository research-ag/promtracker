import PT "mo:promtracker";
import Http "mo:promtracker/mixins/http";
import Uptime "mo:promtracker/mixins/uptime";

actor Main {
  transient let renderer = PT.Renderer();
  include Http(renderer.renderExposition, "/metrics");
  include Uptime();
  renderer.addValue(PT.newValue("uptime_seconds", [], uptime));
};
