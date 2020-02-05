# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Fixed


### Added


### Changed


## [0.5.1] - 2020-02-05

### Fixed

- Include initial ponyup package in lockfile ([PR #89](https://github.com/ponylang/ponyup/pull/89))
- Use `shasum` if `sha256sum` command is missing, or exit with error message ([PR #92](https://github.com/ponylang/ponyup/pull/92))

### Added

- Colorize important ponyup-init.sh output ([PR #81](https://github.com/ponylang/ponyup/pull/81))
- Support showing `$PATH` message for [fish shell](https://fish.sh) ([PR #92](https://github.com/ponylang/ponyup/pull/92))

## [0.5.0] - 2020-01-02

### Added

- Detect platform identifier with init script ([PR #60](https://github.com/ponylang/ponyup/pull/60))

### Changed

- Use unix appdirs for macOS ([PR #69](https://github.com/ponylang/ponyup/pull/69))

## [0.4.0] - 2019-12-27

### Added

- Add macOS support ([PR #56](https://github.com/ponylang/ponyup/pull/56))

## [0.3.1] - 2019-12-19

### Fixed

- Incorrect path usage in ponyup-init.sh

## [0.3.0] - 2019-12-18

### Changed

- Use platform-specific storage paths ([PR #51](https://github.com/ponylang/ponyup/pull/51))

## [0.2.0] - 2019-11-21

### Added

- Add changelog-tool package ([PR #38](https://github.com/ponylang/ponyup/pull/38))
- Add support for release channel ([PR #22](https://github.com/ponylang/ponyup/pull/22))
- Add option to specify ponyc libc
- "Show" enhancements ([PR #47](https://github.com/ponylang/ponyup/pull/47))

## [0.1.0] - 2019-08-25

### Added

- Initial version for updating the nightly release of ponyc, stable, and corral

