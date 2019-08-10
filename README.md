# ponyup

The Pony toolchain multiplexer

## Status

[![CircleCI](https://circleci.com/gh/ponylang/ponyup/tree/master.svg?style=svg)](https://circleci.com/gh/ponylang/ponyup/tree/master)

Ponyup is alpha level software.

## Usage

### Installing ponyup

```bash
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/ponylang/ponyup/master/ponyup-init.sh | sh
```

### Installing Nightly Pony

The following command will download the latest nightly release of Ponyc and install it to `~/.pony/ponyup/bin` by default.

```bash
ponyup update nightly
```

## TODO
- Select default toolchain, rather than symlinking immediately on update
