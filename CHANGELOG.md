# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Fixed


### Added


### Changed

- Switch supported FreeBSD to 13.1 ([PR #238](https://github.com/ponylang/ponyup/pull/238))

## [0.6.8] - 2022-11-24

### Fixed

- Fixed ponyup-init.sh crash when specifying --prefix ([PR #236](https://github.com/ponylang/ponyup/pull/236))

### Changed

- Update Alpine version used for CI to 3.16 (#229) ([PR #230](https://github.com/ponylang/ponyup/pull/230))

## [0.6.7] - 2022-05-28

### Added

- Add ARM64 support ([PR #226](https://github.com/ponylang/ponyup/pull/226))
- Add support for MacOS on Apple Silicon ([PR #228](https://github.com/ponylang/ponyup/pull/228))

## [0.6.6] - 2022-02-11

### Added

- Add Windows support ([PR #214](https://github.com/ponylang/ponyup/pull/214))

## [0.6.5] - 2021-10-05

### Changed

- Update to work with Pony 0.44.0 ([PR #194](https://github.com/ponylang/ponyup/pull/194))

## [0.6.4] - 2021-07-05

### Changed

- Switch supported FreeBSD to 13.0 ([PR #161](https://github.com/ponylang/ponyup/pull/161))

## [0.6.3] - 2021-03-21

### Fixed

- Update Linux builder image ([PR #182](https://github.com/ponylang/ponyup/pull/182))

## [0.6.2] - 2021-03-19

### Fixed

- Fix incorrect FreeBSD to Cloudsmith package mapping ([PR #162](https://github.com/ponylang/ponyup/pull/162))
- Don't prompt for libc type when not on Linux ([PR #179](https://github.com/ponylang/ponyup/pull/179))

### Changed

- Switch FreeBSD supported version to 12.2 ([PR #175](https://github.com/ponylang/ponyup/pull/175))

## [0.6.1] - 2020-08-29

### Fixed

- Incorrect initial ponyup version ([PR #151](https://github.com/ponylang/ponyup/pull/151))
- Fix ponyup-init on freebsd ([PR #156](https://github.com/ponylang/ponyup/pull/156))

## [0.6.0] - 2020-08-20

### Changed

- Use `XDG_DATA_HOME` for install prefix in init script when set ([PR #137](https://github.com/ponylang/ponyup/pull/137))
- Select uses latest version if none is specified ([PR #139](https://github.com/ponylang/ponyup/pull/139))
- Update Dockerfile to Alpine 3.12 ([PR #145](https://github.com/ponylang/ponyup/pull/145))

## [0.5.4] - 2020-06-22

### Fixed

- Fix init script default ([PR #132](https://github.com/ponylang/ponyup/pull/132))

## [0.5.3] - 2020-06-20

### Added

- Prompt user for platform libc if unspecified by target triple ([PR #128](https://github.com/ponylang/ponyup/pull/128))
- Add default command ([PR #129](https://github.com/ponylang/ponyup/pull/129))

## [0.5.2] - 2020-05-23

### Fixed

- Fix cli platform identification ([PR #112](https://github.com/ponylang/ponyup/pull/112))

### Added

- Add FreeBSD support ([PR #113](https://github.com/ponylang/ponyup/pull/113))

### Changed

- Use nightly ponyup on macOS ([PR #122](https://github.com/ponylang/ponyup/pull/122))

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

