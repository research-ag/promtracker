# PromTracker changelog

## 0.5.2

* Fix a bug in share/unshare() that occured when metrics had the same prefix and differed only in label

## 0.5.1

* Expose `sum` and `count` in GaugeInterface

## 0.5.0

* More efficient time calculation

## 0.4.0 (2023-12-31)

* Remove unneeded exports from public module interface (minor breaking change)

## 0.3.0 (2023-12-27)

* Introduce per-value labels
* Gauge values: allow "stable" declaration
* Gauge values: make watermarks optional
* Gauge values: add tracking of `lastValue`
* Counter values: add `sub` function to interface 

## 0.2.0 (2023-11-19)

* Introduce "global" labels, defined once per PromTracker class
* Helper function to get the first 5-character-group of the canister's own principal
* Helper function to generate equi-distant bucket limits 
* 3 new metrics in example canister
* Make tests run by `mops test`
* Code improvements

## 0.1.0 (2023-11-17)

* Initial release
