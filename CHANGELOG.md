# PromTracker changelog

## 1.0.1

- Update documentation

## 1.0.0

- Redesign the interface completely
- Static (no class) Tracker that can be declared stable
- Provide extensive examples and documentation
- Provide Mixins
- Allow nested trackers
- Provide AI skill file to use the package
- Simplify adding system values
- Export metrics also by candid
- Serve openapi.json manifest

## 0.10.0

- Redesign mixin interfaces
- Mixins `tracker, http`
- Labels argument from `renderExposition` removed
- Watermark hold period can change dynamically
- New README
- Bump core dependency

## 0.9.0

- Add mixins/default
- Add mixins/base
- Add comprehensive examples

## 0.8.0

- Add mixins/PtMixin

## 0.7.1

- Update examples
- Fix documentation

## 0.7.0

- Add `http_request` function to `PromTracker` class
- Add `canisterLabel` convenience function

## 0.6.3

- Update documentation

## 0.6.2

- Refactor code
- New implicit argument `now` to pass a time function
- Update examples
- Add and update documentation
- Protect CounterValue against underflows

## 0.6.1

- Switch from base to core 2.0.0

## 0.6.0

- Add all new rts\_ system values
- Bump dependencies
- Rename stablememory_size metric to rts_stable_memory_size
- Add ability to remove metrics by prefix/label
- replace vector dependency by new-base

## 0.5.4

- Bump dependencies

## 0.5.3

- Bump base dependency to 0.11.0

## 0.5.2

- Fix a bug in share/unshare() that occured when metrics had the same prefix and differed only in label

## 0.5.1

- Expose `sum` and `count` in GaugeInterface

## 0.5.0

- More efficient time calculation

## 0.4.0 (2023-12-31)

- Remove unneeded exports from public module interface (minor breaking change)

## 0.3.0 (2023-12-27)

- Introduce per-value labels
- Gauge values: allow "stable" declaration
- Gauge values: make watermarks optional
- Gauge values: add tracking of `lastValue`
- Counter values: add `sub` function to interface

## 0.2.0 (2023-11-19)

- Introduce "global" labels, defined once per PromTracker class
- Helper function to get the first 5-character-group of the canister's own principal
- Helper function to generate equi-distant bucket limits
- 3 new metrics in example canister
- Make tests run by `mops test`
- Code improvements

## 0.1.0 (2023-11-17)

- Initial release
