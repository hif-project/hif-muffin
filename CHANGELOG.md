# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [1.0.0] - 2026-08-12

Initial coordinated release of the HIF toolchain baseline (hif-core, hif-frontend, hif-backend, hif-muffin, all tagged v1.0.0).

- Working `--list-faults`/`--instrument` fault-injection pipeline, verified end-to-end through real `verilog2hif`/`hif2verilog` round trips.
- Added CI (none existed before) and a nightly cross-repo integration workflow that rebuilds all four repos at floating `develop` HEAD and runs each one's test suite.
- Published `docs/known-limitations.md` as the toolchain's compatibility reference.
