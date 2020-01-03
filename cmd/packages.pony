
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
    detect the libc implementation (glibc or musl) for ponyc on Linux-based
    platforms.

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
      else error
      end
    var libc: Libc = if os is Linux then Glibc  end
    for field in platform'.values() do
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
    if (name != "ponyc") or (os is Darwin) then libc = None end
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

class val Package is Comparable[Package box]
  let name: String
  let channel: String
  let version: String
  let cpu: CPU
  let os: OS
  let libc: Libc
  let selected: Bool

  new val _create(
    name': String,
    channel': String,
    version': String,
    platform': (CPU, OS, Libc),
    selected': Bool = false)
  =>
    name = name'
    channel = channel'
    version = version'
    (cpu, os, libc) = platform'
    selected = selected'

  fun update_version(version': String, selected': Bool = false): Package =>
    _create(name, channel, version', (cpu, os, libc), selected')

  fun platform(): String iso^ =>
    let fragments = Array[String]
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

  fun eq(other: Package box): Bool =>
    string() == other.string()

  fun lt(other: Package box): Bool =>
    string() <= other.string()

  fun string(): String iso^ =>
    "-".join([name; channel; version; platform()].values())

type CPU is AMD64
primitive AMD64

type OS is (Linux | Darwin)
primitive Linux
primitive Darwin

type Libc is (None | Glibc | Musl)
primitive Glibc
primitive Musl
