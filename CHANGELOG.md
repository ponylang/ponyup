# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Fixed


### Added


### Changed


## [0.11.1] - 2026-02-02

### Added

- Add Alpine 3.23 as a supported platform ([PR #343](https://github.com/ponylang/ponyup/pull/343))

## [0.11.0] - 2026-01-24

### Added

- Support applications installing more than 1 binary ([PR #342](https://github.com/ponylang/ponyup/pull/342))

### Changed

- Drop Fedora 41 Support ([PR #339](https://github.com/ponylang/ponyup/pull/339))

## [0.10.0] - 2025-10-24

### Added

- Add Alpine 3.22 as a supported platform ([PR #337](https://github.com/ponylang/ponyup/pull/337))

### Changed

- Stop Building Ponyup Docker Images ([PR #334](https://github.com/ponylang/ponyup/pull/334))

## [0.9.1] - 2025-10-09

### Fixed

- Fix broken arm64 Linux release builds ([PR #332](https://github.com/ponylang/ponyup/pull/332))

## [0.9.0] - 2025-10-09

### Added

- Add arm64 Linux builds ([PR #319](https://github.com/ponylang/ponyup/pull/319))
- Add Alpine 3.21 on arm64 as a supported platform ([PR #320](https://github.com/ponylang/ponyup/pull/320))
- Add Alpine 3.21 on x86-64 as a supported platform ([PR #321](https://github.com/ponylang/ponyup/pull/321))
- Add Alpine 3.20 on x86-64 as a supported platform ([PR #322](https://github.com/ponylang/ponyup/pull/322))
- Add Ubuntu 24.04 on arm64 as a supported platform ([PR #323](https://github.com/ponylang/ponyup/pull/323))
- Add Windows on arm64 as a supported platform ([PR #325](https://github.com/ponylang/ponyup/pull/325))

### Changed

- Stop having a base image ([PR #324](https://github.com/ponylang/ponyup/pull/324))

## [0.8.6] - 2025-06-01

### Fixed

- Fix ponyup no longer being able to install programs by version  ([PR #317](https://github.com/ponylang/ponyup/pull/317))

### Changed

- Drop Ubuntu 20.04 support ([PR #315](https://github.com/ponylang/ponyup/pull/315))

## [0.8.5] - 2024-12-27

### Changed

- Use Alpine 3.20 as our base image ([PR #306](https://github.com/ponylang/ponyup/pull/306))
- Drop Fedora 39 Support ([PR #309](https://github.com/ponylang/ponyup/pull/309))

## [0.8.4] - 2024-12-08

### Added

- Add Fedora 41 Support ([PR #308](https://github.com/ponylang/ponyup/pull/308))

## [0.8.3] - 2024-04-27

### Added

- Add Ubuntu 24.04 support ([PR #303](https://github.com/ponylang/ponyup/pull/303))

## [0.8.2] - 2024-02-02

### Added

- Add MacOS on Apple Silicon as a fully supported platform ([PR #290](https://github.com/ponylang/ponyup/pull/290))

## [0.8.1] - 2024-01-30

### Added

- Add support for Fedora 39 ([PR #289](https://github.com/ponylang/ponyup/pull/289))

### Changed

- Update base image to Alpine 3.18 ([PR #268](https://github.com/ponylang/ponyup/pull/268))

## [0.8.0] - 2023-08-30

### Added

- Add macOS on Intel as a fully supported platform ([PR #257](https://github.com/ponylang/ponyup/pull/257))

### Changed

- Change supported MacOS version to Ventura ([PR #250](https://github.com/ponylang/ponyup/pull/250))
- Drop Ubuntu 18.04 support ([PR #252](https://github.com/ponylang/ponyup/pull/252))
- Drop FreeBSD support ([PR #255](https://github.com/ponylang/ponyup/pull/255))
- Temporarily drop macOS on Apple Silicon as fully supported platform ([PR #258](https://github.com/ponylang/ponyup/pull/258))

## [0.7.0] - 2023-01-20

### Changed

- Remove macOS on Intel support ([PR #240](https://github.com/ponylang/ponyup/pull/240))
- Never use the "generic gnu" ponyc package ([PR #245](https://github.com/ponylang/ponyup/pull/245))

## [0.6.9] - 2022-12-02

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

