import PT "../../src/lib";

module {
  public func removeCtr2(
    old : {
      pt : PT.Tracker;
      ctr2 : PT.Counter.Counter;
    }
  ) : { pt : PT.Tracker } {
    old.pt.removeValue(old.ctr2);
    {
      pt = old.pt;
    };
  };
}
