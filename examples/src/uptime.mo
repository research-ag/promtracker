import PT "../../src/lib";
import Http "../../src/mixins/http";
import Uptime "../../src/mixins/uptime";

persistent actor Main {
  transient let renderer = PT.Renderer();
  include Http(renderer.renderExposition, "/metrics");
  include Uptime();
  renderer.addValue(PT.newValue("uptime_seconds", [], uptime));
};
