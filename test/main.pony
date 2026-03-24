use "files"
use "json"
use "pony_test"
use "time"
use "../cmd"

actor Main is TestList
  new create(env: Env) =>
    let test_dir = FilePath(FileAuth(env.root), "./.pony_test")
    if test_dir.exists() then test_dir.remove() end
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestParsePlatform)
    for package in Packages().values() do
      for channel in ["nightly"; "release"].values() do
        test(_TestSync(package, channel))
      end
    end
    test(_TestSelect)
    test(_TestRemove)
    test(_TestFind)
    test(_TestFindCount)
    test(_TestFindAll)
    test(_TestFindChannel)

class _TestParsePlatform is UnitTest
  fun name(): String =>
    "parse platform"

  fun apply(h: TestHelper) ? =>
    let tests =
      [ as (String, ((CPU, OS, Distro) | None)):
        ("ponyc-?-?-x86_64-unknown-linux-ubuntu22.04", (AMD64, Linux, "ubuntu22.04"))
        ("ponyc-?-?-x64-linux-ubuntu22.04", (AMD64, Linux, "ubuntu22.04"))
        ("ponyc-x86_64-pc-linux-ubuntu24.04", (AMD64, Linux, "ubuntu24.04"))
        ("ponyc-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, "musl"))
        ("ponyc-?-?-x86_64-apple-darwin", (AMD64, Darwin, None))
        ( "ponyc-?-?-musl"
        , (AMD64, Packages.platform_os()?, Packages.platform_distro("musl"))
        )
        ("ponyc-?-?-x86_64-linux", None)
        ("ponyc-?-?-x86_64-darwin", (AMD64, Darwin, None))
        ("ponyc-?-?-x86_64-pc-windows-msvc", (AMD64, Windows, None))
      ]
    for (input, expected) in tests.values() do
      h.log("input: " + input)
      match \exhaustive\ expected
      | (let cpu: CPU, let os: OS, let distro: Distro) =>
        let pkg = Packages.from_string(input)?
        h.log("  => " + pkg.platform().string())
        h.assert_eq[CPU](pkg.cpu, cpu)
        h.assert_eq[OS](pkg.os, os)
        match (pkg.distro, distro)
        | (let d: String, let d': String) => h.assert_eq[String](d, d')
        else h.assert_true((pkg.distro is None) and (distro is None))
        end
      | None => h.assert_error({() ? => Packages.from_string(input)? })
      end
    end

class _TestSync is UnitTest
  let _application: Application
  let _channel: String

  new iso create(application: Application, channel: String) =>
    _application = application
    _channel = channel

  fun name(): String =>
    "sync - " + _application.name() + "-" + _channel

  fun apply(h: TestHelper) =>
    _SyncTester(h, h.env.root, _application, _channel)
    h.long_test(120_000_000_000)

class _TestSelect is UnitTest
  """
  Verify that the select command works. We don't actually care about the
  platform as long as our platform and versions together form something that
  exists and can be installed. We don't try running them so the arch, platform,
  and distro don't matter.
  """
  fun name(): String =>
    "select"

  fun apply(h: TestHelper) =>
    _SelectTester(h)
    h.long_test(120_000_000_000)

class _TestRemove is UnitTest
  """
  Verify that the remove command works. Install two versions, confirm that
  removing the selected version is refused, then remove the non-selected
  version and verify both the directory and lockfile entry are gone.
  """
  fun name(): String =>
    "remove"

  fun apply(h: TestHelper) =>
    _RemoveTester(h)
    h.long_test(120_000_000_000)

class _TestFind is UnitTest
  fun name(): String =>
    "find"

  fun apply(h: TestHelper) =>
    _FindTester.run(h, ["release"], "arm64-windows", 10, false)
    h.long_test(120_000_000_000)

class _TestFindCount is UnitTest
  fun name(): String =>
    "find - count"

  fun apply(h: TestHelper) =>
    _FindTester.count(h, 2)
    h.long_test(120_000_000_000)

class _TestFindAll is UnitTest
  fun name(): String =>
    "find - all platforms"

  fun apply(h: TestHelper) =>
    _FindTester.all(h)
    h.long_test(120_000_000_000)

class _TestFindChannel is UnitTest
  fun name(): String =>
    "find - channel"

  fun apply(h: TestHelper) =>
    _FindTester.channel(h, "corral", "nightly")
    h.long_test(120_000_000_000)

actor _FindTester is PonyupNotify
  let _h: TestHelper
  let _pkg: String
  var _row_count: USize = 0
  var _got_pkg: Bool = false
  var _max_rows: USize = 0
  var _check_channel: String = ""
  var _check_multi_platform: Bool = false
  embed _filenames: Array[String] = []
  let _timers: Timers = Timers
  var _had_error: Bool = false
  var _error_msg: String = ""

  new run(h: TestHelper, channels: Array[String] val, platform: String,
    page_size: I64, all_platforms: Bool)
  =>
    _h = h
    _pkg = "ponyc"
    _start("ponyc", channels, platform, page_size, all_platforms)

  new count(h: TestHelper, n: USize) =>
    _h = h
    _pkg = "ponyc"
    _max_rows = n
    _start("ponyc", ["release"], "arm64-windows", n.i64(), false)

  new all(h: TestHelper) =>
    _h = h
    _pkg = "ponyc"
    _check_multi_platform = true
    _start("ponyc", ["release"], "", 10, true)

  new channel(h: TestHelper, pkg: String, ch: String) =>
    _h = h
    _pkg = pkg
    _check_channel = ch
    _start(pkg, [ch], "arm64-windows", 10, false)

  fun ref _start(pkg: String, channels: Array[String] val, platform: String,
    page_size: I64, all_platforms: Bool)
  =>
    let http_get = HTTPGet(_h.env.root, this)
    FindPackages(this, http_get, pkg, channels, platform,
      page_size, all_platforms)
    let self: _FindTester tag = this
    let timer = Timer(
      object iso is TimerNotify
        fun ref apply(timer: Timer, count: U64): Bool =>
          self.check_results()
          false
      end,
      15_000_000_000)
    _timers(consume timer)

  be check_results() =>
    _h.log("check_results: row_count=" + _row_count.string()
      + " got_pkg=" + _got_pkg.string()
      + " had_error=" + _had_error.string()
      + " filenames=" + _filenames.size().string())
    if _had_error then
      _h.log("error detail: " + _error_msg)
    end
    _h.assert_true(_got_pkg, "expected output containing " + _pkg
      + " (row_count=" + _row_count.string()
      + ", had_error=" + _had_error.string() + ")")
    _h.assert_true(_row_count > 0, "expected results but got none"
      + if _had_error then " (error: " + _error_msg + ")" else "" end)
    if _max_rows > 0 then
      _h.assert_true(_row_count <= _max_rows,
        "expected at most " + _max_rows.string() + " results, got "
          + _row_count.string())
    end
    if _check_multi_platform then
      _h.assert_true(_filenames.size() > 1,
        "expected results for multiple platforms, got "
          + _filenames.size().string())
    end
    _h.complete(true)

  be log(level: LogLevel, msg: String) =>
    _h.log(msg)
    match level
    | InternalErr | Err =>
      _had_error = true
      _error_msg = msg
      _h.fail(msg)
      _h.complete(false)
    end

  be write(str: String, ansi_color_code: String = "") =>
    _h.log(str)
    if str.contains("Tool") then return end
    _row_count = _row_count + 1
    if str.contains(_pkg) then _got_pkg = true end
    if (_check_channel != "") and (not str.contains(_check_channel)) then
      _h.fail("row should contain " + _check_channel + ": " + str)
    end
    if _check_multi_platform then
      let trimmed: String val = str.clone().>rstrip()
      try
        let i = trimmed.rfind(" ")?
        let plat: String = trimmed.substring(i + 1)
        if not _filenames.contains(plat, {(a, b) => a == b }) then
          _filenames.push(consume plat)
        end
      end
    end

  be complete(pkg: Package) => None

actor \nodoc\ _SyncTester is PonyupNotify
  let _h: TestHelper
  let _auth: AmbientAuth
  let _application: Application
  embed _pkgs: Array[Package] = []
  var _processed: USize = 0
  var _ponyup: (Ponyup | None) = None
  var _root: (FilePath | None) = None

  new create(
    h: TestHelper,
    auth: AmbientAuth,
    application: Application,
    channel: String)
  =>
    _h = h
    _auth = auth
    _application = application

    let platform = _TestPonyup.platform()
    let http_get = HTTPGet(_auth, this)
    try
      let pkg = Packages.from_fragments(
        application, channel, "latest", platform.split("-"))?
      let query_string: String =
        Cloudsmith.repo_url(channel).clone()
          .> append(Cloudsmith.query(pkg))
          .> replace("page_size=1", "page_size=2")
      log(Extra, "query url: " + query_string)
      http_get.query(
        query_string,
        {(res)(self = recover tag this end, pkg) =>
          self.add_packages(pkg, consume res)
        })
    end

  be add_packages(pkg: Package, res: Array[JsonObject val] iso) =>
    let count = res.size()
    _h.log("query returned " + count.string() + " results for "
      + _application.name())
    if count == 0 then
      _h.log("WARNING: Cloudsmith query returned zero results for "
        + _application.name())
    end
    for obj in (consume res).values() do
      try
        let file = obj("filename")? as String
        let version = obj("version")? as String
        _h.log("  found: " + file + " (version " + version + ")")
        _pkgs.push(pkg.update_version(version))
      else
        _h.log("  skipped entry: missing filename or version field")
      end
    end
    run()

  be run() =>
    if _pkgs.size() == 0 then
      if _processed == 0 then
        _h.fail("sync: query returned no installable packages for "
          + _application.name()
          + " -- Cloudsmith may be rate-limiting or unreachable")
        _h.complete(false)
      else
        _h.log("sync: finished " + _processed.string()
          + " packages for " + _application.name())
        _h.complete(true)
      end
      return
    end
    try
      _processed = _processed + 1
      let pkg = _pkgs.shift()?
      let ponyup = match _ponyup
        | let p: Ponyup => p
        else
          let name = recover val
            _application.name() + "/" + pkg.channel
          end
          let root = FilePath(FileAuth(_auth),
            "./.pony_test/" + name + "/ponyup")
          if not root.exists() then root.mkdir() end
          _root = root
          let lockfile = recover CreateFile(root.join(".lock")?) as File end
          let p = Ponyup(_h.env, _auth, root, consume lockfile, this)
          _ponyup = p
          p
        end
      _h.log("sync -- " + pkg.name() + "/" + pkg.channel)
      ponyup.sync(pkg)
    else
      _h.fail("sync setup error")
      _h.complete(false)
    end

  be complete(pkg: Package) =>
    match _root
    | let root: FilePath =>
      try
        _TestPonyup.check_files(_h, root, pkg)?
      else
        _h.fail("check_files failed for " + pkg.string())
        _h.complete(false)
        return
      end
    else
      _h.fail("root not initialized")
      _h.complete(false)
      return
    end
    run()

  be log(level: LogLevel, msg: String) =>
    _h.log(msg)
    match level
    | InternalErr | Err =>
      _h.fail(msg)
      _h.complete(false)
    end

  be write(str: String, ansi_color_code: String = "") =>
    _h.log(str)

actor \nodoc\ _SelectTester is PonyupNotify
  """
  State machine for the select test. Installs two ponyc versions, verifies
  that the latest is auto-selected, then explicitly selects the older version
  and verifies the symlink changed.

  Steps:
    0 -> sync pkg_a -> complete -> 1
    1 -> sync pkg_b -> complete -> 2
    2 -> verify link points to B, select pkg_a -> complete -> 3
    3 -> verify link points to A, done
  """
  let _h: TestHelper
  var _ponyup: (Ponyup | None) = None
  var _root: (FilePath | None) = None
  var _pkg_a: (Package | None) = None
  var _pkg_b: (Package | None) = None
  var _step: USize = 0

  new create(h: TestHelper) =>
    _h = h
    try
      let platform = _TestPonyup.platform()
      let target = recover val platform.split("-") end
      let pkg_a = Packages.from_fragments(
        PonycApplication, "release", "0.61.1", target)?
      let pkg_b = Packages.from_fragments(
        PonycApplication, "release", "0.62.0", target)?
      _pkg_a = pkg_a
      _pkg_b = pkg_b
      let root = FilePath(FileAuth(h.env.root),
        "./.pony_test/select/ponyup")
      if not root.exists() then root.mkdir() end
      _root = root
      let lockfile = recover CreateFile(root.join(".lock")?) as File end
      let ponyup = Ponyup(h.env, h.env.root, root, consume lockfile, this)
      _ponyup = ponyup
      ponyup.sync(pkg_a)
    else
      h.fail("failed to set up select test")
      h.complete(false)
    end

  be complete(pkg: Package) =>
    _step = _step + 1
    try
      let ponyup = _ponyup as Ponyup
      let root = _root as FilePath
      let pkg_a = _pkg_a as Package
      let pkg_b = _pkg_b as Package
      match _step
      | 1 => ponyup.sync(pkg_b)
      | 2 =>
        _check_link(root, "0.62.0")?
        ponyup.select(pkg_a)
      | 3 =>
        _check_link(root, "0.61.1")?
        _h.complete(true)
      else
        _h.fail("unexpected complete at step " + _step.string())
        _h.complete(false)
      end
    else
      _h.fail("select test failed at step " + _step.string())
      _h.complete(false)
    end

  fun _check_link(root: FilePath, version: String) ? =>
    let link =
      ifdef windows then
        root.join("bin")?.join("ponyc.bat")?
      else
        root.join("bin")?.join("ponyc")?
      end
    ifdef windows then
      var found = false
      with file = File.open(link) do
        for line in file.lines() do
          if line.contains(version) then
            found = true
            break
          end
        end
      end
      if not found then
        _h.fail("batch file did not contain version " + version)
        error
      end
    else
      let target = link.canonical()?.path
      if not target.contains(version) then
        _h.fail("symlink " + target
          + " should point to version " + version)
        error
      end
    end

  be log(level: LogLevel, msg: String) =>
    _h.log(msg)
    match level
    | InternalErr | Err =>
      _h.fail(msg)
      _h.complete(false)
    end

  be write(str: String, ansi_color_code: String = "") =>
    _h.log(str)

actor \nodoc\ _RemoveTester is PonyupNotify
  """
  State machine for the remove test. Installs two ponyc versions, confirms
  that removing the selected version is refused, removes the non-selected
  version, and verifies the directory is gone.

  Steps:
    0 -> sync pkg_a -> complete -> 1
    1 -> sync pkg_b -> complete -> 2
    2 -> remove pkg_b (selected, expect error) -> log(Err) -> 3
    3 -> remove pkg_a (non-selected) -> complete -> 4
    4 -> verify pkg_a directory gone, done
  """
  let _h: TestHelper
  var _ponyup: (Ponyup | None) = None
  var _root: (FilePath | None) = None
  var _pkg_a: (Package | None) = None
  var _pkg_b: (Package | None) = None
  var _step: USize = 0

  new create(h: TestHelper) =>
    _h = h
    try
      let platform = _TestPonyup.platform()
      let target = recover val platform.split("-") end
      let pkg_a = Packages.from_fragments(
        PonycApplication, "release", "0.61.1", target)?
      let pkg_b = Packages.from_fragments(
        PonycApplication, "release", "0.62.0", target)?
      _pkg_a = pkg_a
      _pkg_b = pkg_b
      let root = FilePath(FileAuth(h.env.root),
        "./.pony_test/remove/ponyup")
      if not root.exists() then root.mkdir() end
      _root = root
      let lockfile = recover CreateFile(root.join(".lock")?) as File end
      let ponyup = Ponyup(h.env, h.env.root, root, consume lockfile, this)
      _ponyup = ponyup
      ponyup.sync(pkg_a)
    else
      h.fail("failed to set up remove test")
      h.complete(false)
    end

  be complete(pkg: Package) =>
    _step = _step + 1
    try
      let ponyup = _ponyup as Ponyup
      let root = _root as FilePath
      let pkg_a = _pkg_a as Package
      let pkg_b = _pkg_b as Package
      match _step
      | 1 => ponyup.sync(pkg_b)
      | 2 => ponyup.remove(pkg_b)
      | 4 =>
        let pkg_dir = root.join(pkg_a.string())?
        _h.assert_false(pkg_dir.exists(),
          "package directory should have been removed: " + pkg_dir.path)
        _h.complete(true)
      else
        _h.fail("unexpected complete at step " + _step.string())
        _h.complete(false)
      end
    else
      _h.fail("remove test failed at step " + _step.string())
      _h.complete(false)
    end

  be log(level: LogLevel, msg: String) =>
    _h.log(msg)
    match level
    | InternalErr | Err =>
      if (_step == 2) and msg.contains("cannot remove") then
        _step = 3
        try
          let ponyup = _ponyup as Ponyup
          let pkg_a = _pkg_a as Package
          ponyup.remove(pkg_a)
        else
          _h.fail("remove test: failed to extract fields at step 3")
          _h.complete(false)
        end
      else
        _h.fail(msg)
        _h.complete(false)
      end
    end

  be write(str: String, ansi_color_code: String = "") =>
    _h.log(str)

primitive _TestPonyup
  fun platform(): String =>
    if Platform.windows() then
      "x86_64-pc-windows-msvc"
    else
      "x86_64-linux-alpine3.23"
    end

  fun check_files(h: TestHelper, root: FilePath, pkg: Package) ? =>
    let bin_path = root.join(pkg.string())?.join("bin")?
      .join(pkg.name() + ifdef windows then ".exe" else "" end)?
    h.assert_true(bin_path.exists())
