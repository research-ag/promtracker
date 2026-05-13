import PT "../../src/lib";
import Http "../../src/mixins/http";

persistent actor Main {
  transient let renderer = PT.Renderer();
  include Http(renderer.renderExposition, "/metrics");
  renderer.addCanisterLabel(Main);
  transient let subRenderer = PT.Renderer();
  renderer.addValue(subRenderer);
  subRenderer.addLabel("level", "1");
  subRenderer.addValue(
    [
      PT.cyclesBalanceMetric,
      PT.canisterVersionMetric,
    ].bundle([])
  );
};
