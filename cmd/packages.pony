
primitive Packages
  fun apply(): Array[String] box =>
    ["changelog-tool"; "corral"; "ponyc"; "ponyup"; "stable"]

  fun from_fragments(
    name: String,
    channel: String,
    version: String,
    platform: Array[String] box)
    : Package ?
  =>
    var cpu: CPU = AMD64
    var os: OS =
      if Platform.linux() then Linux
      elseif Platform.osx() then Darwin
      else error
      end
    var libc: Libc =
      if name == "ponyc" then Glibc
      else None
      end
    for field in platform.values() do
      match field
      | "x86_64" | "x64" | "amd64" => cpu = AMD64
      | "linux" => os = Linux
      | "darwin" => os = Darwin
      | "gnu" => libc = Glibc
      | "musl" => libc = Musl
      | "none" | "unknown" | "pc" | "apple" => None
      else error
      end
    end
    Package._create(name, channel, version, (cpu, os, libc))

  fun from_string(str: String): Package ? =>
    let fragments = str.split("-")
    match (fragments(0)?, fragments(1)?)
    | ("changelog", "tool") =>
      fragments.delete(1)?
      fragments(0)? = "changelog-tool"
    end
    from_fragments(
      fragments(0)?,
      fragments(1)?,
      fragments(2)?,
      (consume fragments).slice(3))?

class val Package
  let name: String
  let channel: String
  let version: String
  let cpu: CPU
  let os: OS
  let libc: Libc

  new val _create(
    name': String,
    channel': String,
    version': String,
    platform': (CPU, OS, Libc))
  =>
    name = name'
    channel = channel'
    version = version'
    (cpu, os, libc) = platform'

  fun update_version(version': String): Package =>
    _create(name, channel, version', (cpu, os, libc))

  fun string(): String iso^ =>
    let fragments = [name; channel; version]
    match cpu
    | AMD64 => fragments.push("x86_64")
    end
    match os
    | Linux => fragments.push("linux")
    | Darwin => fragments.push("darwin")
    end
    if name == "ponyc" then
      match libc
      | Glibc => fragments.push("gnu")
      | Musl => fragments.push("musl")
      end
    end
    "-".join(fragments.values())

type CPU is AMD64
primitive AMD64

type OS is (Linux | Darwin)
primitive Linux
primitive Darwin

type Libc is (None | Glibc | Musl)
primitive Glibc
primitive Musl
