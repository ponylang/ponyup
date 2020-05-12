
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
    """
    Parse the target indentifier fields extracted from a target triple.

    It is assumed that Arch field does not contain a `-` character, such as
    x86-64 which must be replaced by either x86_64, x64, or amd64. Vendor
    fields (unknown, pc, apple, etc.) are ignored. ABI fields are used to
    detect the libc implementation (glibc or musl) or distribution (ubuntu18.04)
    for ponyc on Linux-based platforms.

    See also https://clang.llvm.org/docs/CrossCompilation.html#target-triple
    """
    let platform' = (consume platform).clone()
    // ignore vendor identifier in full target triple
    if platform'.size() > 3 then
      platform'.trim_in_place(0, 4)
      try platform'.delete(1)? end
    end
    var cpu: CPU = AMD64
    var os: OS =
      if Platform.linux() then Linux
      elseif Platform.osx() then Darwin
      elseif Platform.freebsd() then FreeBSD
      else error
      end
    var distro: Distro = if os is Linux then "gnu" end
    for (i, field) in platform'.pairs() do
      match field
      | "x86_64" | "x64" | "amd64" => cpu = AMD64
      | "linux" => os = Linux
      | "darwin" => os = Darwin
      | "freebsd" => os = FreeBSD
      | "none" | "unknown" | "pc" | "apple" => None
      else
        if i == (platform'.size() - 1) then distro = field end
      end
    end
    if (name != "ponyc") or (os is Darwin) or (os is FreeBSD) then
      distro = None
    end
    Package._create(name, channel, version, (cpu, os, distro))

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

class val Package is Comparable[Package box]
  let name: String
  let channel: String
  let version: String
  let cpu: CPU
  let os: OS
  let distro: Distro
  let selected: Bool

  new val _create(
    name': String,
    channel': String,
    version': String,
    platform': (CPU, OS, Distro),
    selected': Bool = false)
  =>
    name = name'
    channel = channel'
    version = version'
    (cpu, os, distro) = platform'
    selected = selected'

  fun update_version(version': String, selected': Bool = false): Package =>
    _create(name, channel, version', (cpu, os, distro), selected')

  fun platform(): String iso^ =>
    let fragments = Array[String]
    match cpu
    | AMD64 => fragments.push("x86_64")
    end
    match os
    | Linux => fragments.push("linux")
    | Darwin => fragments.push("darwin")
    | FreeBSD => fragments.push("freebsd")
    end
    if name == "ponyc" then
      match distro
      | let distro_name: String => fragments.push(distro_name)
      end
    end
    "-".join(fragments.values())

  fun eq(other: Package box): Bool =>
    string() == other.string()

  fun lt(other: Package box): Bool =>
    string() <= other.string()

  fun string(): String iso^ =>
    "-".join([name; channel; version; platform()].values())

type CPU is AMD64
primitive AMD64

type OS is (Linux | Darwin | FreeBSD)
primitive Linux
primitive Darwin
primitive FreeBSD

type Distro is (None | String)
