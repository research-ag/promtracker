import Int "mo:core/Int";
import Time "mo:core/Time";

mixin () {
  transient let canister_start_time = Time.now();

  func uptime() : Nat = Int.abs(Time.now() - canister_start_time) / 1_000_000_000;
};
