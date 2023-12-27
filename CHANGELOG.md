# PromTracker changelog

## 0.3.0 (2023-12-27)

Changes to gauge values:  
* Gauge values: allow "stable" declaration
* Gauge values: make watermarks optional
* Gauge values: add tracking of `lastValue`
* Counter values: add `sub` function to interface 
* Allow per-value labels

## 0.2.0 (2023-11-19)

* Introduce "global" labels, defined once per PromTracker class
* Helper function to get the first 5-character-group of the canister's own principal
* Helper function to generate equi-distant bucket limits 
* 3 new metrics in example canister
* Make tests run by `mops test`
* Code improvements

## 0.1.0 (2023-11-17)

* Initial release
