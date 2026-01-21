trait val PackageFoo
  fun name(): String
  fun required_binaries(): Array[String] val
  fun optional_binaries(): Array[String] val

primitive CorralPackage is PackageFoo
  fun name(): String => "corral"
  fun required_binaries(): Array[String] val => ["corral"]
  fun optional_binaries(): Array[String] val => []

primitive PonycPackage is PackageFoo
  fun name(): String => "ponyc"
  fun required_binaries(): Array[String] val => ["ponyc"]
  fun optional_binaries(): Array[String] val => ["pony-lsp"]

primitive PonyupPackage is PackageFoo
  fun name(): String => "ponyup"
  fun required_binaries(): Array[String] val => ["ponyup"]
  fun optional_binaries(): Array[String] val => []

primitive ChangelogToolPackage is PackageFoo
  fun name(): String => "changelog-tool"
  fun required_binaries(): Array[String] val => ["changelog-tool"]
  fun optional_binaries(): Array[String] val => []

primitive StablePackage is PackageFoo
  fun name(): String => "stable"
  fun required_binaries(): Array[String] val => ["stable"]
  fun optional_binaries(): Array[String] val => []

primitive Packages
  fun apply(): Array[PackageFoo] box =>
    ifdef windows then
      [CorralPackage; PonycPackage; PonyupPackage]
    else
      [
        CorralPackage
        PonycPackage
        PonyupPackage
        ChangelogToolPackage
        StablePackage
      ]
    end

  fun package_from_string(name: String): PackageFoo ? =>
    match name
    | "ponyc" => PonycPackage
    | "corral" => CorralPackage
    | "ponyup" => PonyupPackage
    | "changelog-tool" => ChangelogToolPackage
    | "stable" => StablePackage
    else
      error
    end
     
  fun from_fragments(
    package: PackageFoo,
    channel: String,
    version: String,
    platform: Array[String] box)
    : Package ?
  =>
    """
    Parse the target indentifier fields extracted from a target triple.

    It is assumed that Arch field does not contain a `-` character, such as
    x86-64 which must be replaced by either x86_64, x64, or amd64. Vendor fields
    (unknown, pc, apple, etc.) are ignored. ABI fields are used to detect the
    libc implementation (glibc or musl) or distribution (ubuntu24.04) on
    Linux-based platforms. Such ABI fields are required for Linux for some
    packages, such as ponyc.

    See also https://clang.llvm.org/docs/CrossCompilation.html#target-triple
    """
    let platform' = (consume platform).clone()
    // ignore vendor identifier in full target triple
    if platform'.size() > 3 then
      platform'.trim_in_place(0, 4)
      try platform'.delete(1)? end
    end
    var cpu: CPU = AMD64
    var os: OS = platform_os()?
    var distro: Distro = None
    for (i, field) in platform'.pairs() do
      match field
      | "x86_64" | "x64" | "amd64" => cpu = AMD64
      | "arm64" => cpu = ARM64
      | "linux" => os = Linux
      | "darwin" => os = Darwin
      | "windows" => os = Windows
      else
        if i == (platform'.size() - 1) then distro = field end
      end
    end
    if (package.name() == "ponyc") and platform_requires_distro(os) then
      if distro is None then error end
    else
      distro = None
    end
    Package._create(package, channel, version, (cpu, os, distro))

  fun from_string(str: String): Package ? =>
    let fragments = str.split("-")
    match (fragments(0)?, fragments(1)?)
    | ("changelog", "tool") =>
      fragments.delete(1)?
      fragments(0)? = "changelog-tool"
    end

    from_fragments(
      package_from_string(fragments(0)?)?,
      fragments(1)?,
      fragments(2)?,
      (consume fragments).slice(3))?

  fun platform_os(): OS ? =>
    if Platform.osx() then Darwin
    elseif Platform.linux() then Linux
    elseif Platform.windows() then Windows
    else error
    end

  fun platform_distro(distro: String): Distro =>
    if Platform.linux() then distro end

  fun platform_requires_distro(os: OS): Bool =>
    match os
    | Linux => true
    | Darwin => false
    | Windows => false
    end

class val Package is Comparable[Package box]
  let package: PackageFoo
  let channel: String
  let version: String
  let cpu: CPU
  let os: OS
  let distro: Distro
  let selected: Bool

  new val _create(
    package': PackageFoo,
    channel': String,
    version': String,
    platform': (CPU, OS, Distro),
    selected': Bool = false)
  =>
    package = package'
    channel = channel'
    version = version'
    (cpu, os, distro) = platform'
    selected = selected'

  fun name(): String =>
    package.name()
  
  fun update_version(version': String, selected': Bool = false): Package =>
    _create(package, channel, version', (cpu, os, distro), selected')

  fun platform(): String iso^ =>
    let str = "-".join([cpu; os].values())
    match (package.name() == "ponyc", distro)
    | (true, let distro_name: String) => str.append("-" + distro_name)
    end
    str

  fun eq(other: Package box): Bool =>
    string() == other.string()

  fun lt(other: Package box): Bool =>
    string() <= other.string()

  fun string(): String iso^ =>
    "-".join([package.name(); channel; version; platform()].values())

type CPU is ((AMD64 | ARM64) & _CPU)
interface val _CPU is (Equatable[_OS] & Stringable)
primitive AMD64 is _OS
  fun string(): String iso^ => "x86_64".string()
primitive ARM64 is _OS
  fun string(): String iso^ => "arm64".string()

type OS is ((Linux | Darwin | Windows) & _OS)
interface val _OS is (Equatable[_OS] & Stringable)
primitive Linux is _OS
  fun string(): String iso^ => "linux".string()
primitive Darwin is _OS
  fun string(): String iso^ => "darwin".string()
primitive Windows is _OS
  fun string(): String iso^ => "windows".string()

type Distro is (None | String)
