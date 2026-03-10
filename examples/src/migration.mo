import { Counter } "../../src/lib";

module {
  public func removeCtr2(
    old : {
      ctr2 : Counter.Counter;
    }
  ) : {} {
    old.ctr2.unregister();
    {};
  };
};
