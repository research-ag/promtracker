import Tracker "../../src/Tracker";

module {
  public func removeCtr2(
    old : {
      pt : Tracker.Tracker;
      ctr2 : Tracker.Counter;
    }
  ) : { pt : Tracker.Tracker } {
    old.pt.removeValue(old.ctr2);
    {
      pt = old.pt;
    };
  };
}
