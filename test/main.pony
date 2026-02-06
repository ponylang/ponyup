use "backpressure"
use "files"
use "json"
use "net"
use "pony_test"
use "process"
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
      match expected
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
  let _ponyc_versions: Array[String] val =
    ["release-0.58.13"; "release-0.59.0"]

  fun name(): String =>
    "select"

  fun apply(h: TestHelper) ? =>
    let platform = _TestPonyup.platform()
    let install_args: {(String): Array[String] val} val =
      {(v) => ["update"; "ponyc"; v; "--platform=" + platform] }

    let link_path =
      ifdef windows then
        "./.pony_test/select/ponyup/bin/ponyc.bat"
      else
        "./.pony_test/select/ponyup/bin/ponyc"
      end
    let link = FilePath(FileAuth(h.env.root), link_path)

    let check =
      {()? =>
        ifdef windows then
          var found = false
          with file = File.open(link) do
            for line in file.lines() do
              if line.contains(_ponyc_versions(1)?) then
                found = true
                break
              end
            end
          end
          h.assert_true(found, "batch file 0 did not contain the correct path")
        else
          h.assert_true(link.canonical()?.path.contains(_ponyc_versions(1)?))
        end

        _TestPonyup.exec(
          h, "select", ["select"; "ponyc" ; _ponyc_versions(0)?; "--platform=" + platform],
          {()? =>
            ifdef windows then
              with file = File.open(link) do
                for line in file.lines() do
                  if line.contains(_ponyc_versions(0)?) then
                    h.complete(true)
                    return
                  end
                end
              end
              h.fail("batch file did not contain the correct path")
              h.complete(false)
            else
              h.assert_true(
                link.canonical()?.path.contains(_ponyc_versions(0)?))
              h.complete(true)
            end
          } val)?
      } val

    _TestPonyup.exec(
      h, "select", install_args(_ponyc_versions(0)?),
      {()(check) =>
        try
          _TestPonyup.exec(
            h, "select", install_args(_ponyc_versions(1)?),
            {()? => check()? } val)?
        else
          h.complete(false)
        end
      } val)?

    h.long_test(120_000_000_000)

class _TestFind is UnitTest
  fun name(): String =>
    "find"

  fun apply(h: TestHelper) =>
    _FindTester.run(h, ["release"], "x86_64-linux-musl", 10, false)
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
    _start("ponyc", ["release"], "x86_64-linux-musl", n.i64(), false)

  new all(h: TestHelper) =>
    _h = h
    _pkg = "ponyc"
    _check_multi_platform = true
    _start("ponyc", ["release"], "", 10, true)

  new channel(h: TestHelper, pkg: String, ch: String) =>
    _h = h
    _pkg = pkg
    _check_channel = ch
    _start(pkg, [ch], "x86_64-linux", 10, false)

  fun ref _start(pkg: String, channels: Array[String] val, platform: String,
    page_size: I64, all_platforms: Bool)
  =>
    let http_get = HTTPGet(NetAuth(_h.env.root), this)
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
    _h.assert_true(_got_pkg, "expected output containing " + _pkg)
    _h.assert_true(_row_count > 0, "expected results")
    if _max_rows > 0 then
      _h.assert_true(_row_count <= _max_rows,
        "expected at most " + _max_rows.string() + " results, got "
          + _row_count.string())
    end
    if _check_multi_platform then
      _h.assert_true(_filenames.size() > 1,
        "expected results for multiple platforms")
    end
    _h.complete(true)

  be log(level: LogLevel, msg: String) =>
    match level
    | InternalErr | Err =>
      _h.fail(msg)
      _h.complete(false)
    else
      _h.env.out.print(msg)
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

actor _SyncTester is PonyupNotify
  let _h: TestHelper
  let _auth: AmbientAuth
  let _application: Application
  embed _pkgs: Array[Package] = []

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
    let http_get = HTTPGet(NetAuth(_auth), this)
    try
      let pkg = Packages.from_fragments(
        application, channel, "latest", platform.split("-"))?
      let query_string: String =
        Cloudsmith.repo_url(channel).clone()
          .> append(Cloudsmith.query(pkg))
          .> replace("page_size=1", "page_size=2")
      log(Extra, "query url: " + query_string)
      http_get(
        query_string,
        {(_)(self = recover tag this end, pkg) =>
          QueryHandler(self, {(res) => self.add_packages(pkg, consume res) })
        })
    end

  be add_packages(pkg: Package, res: Array[JsonObject val] iso) =>
    for obj in (consume res).values() do
      try
        let file = obj.data("filename")? as String
        _pkgs.push(pkg.update_version(obj.data("version")? as String))
      end
    end
    run()

  be run() =>
    if _pkgs.size() == 0 then
      _h.complete(true)
      return
    end
    try
      let pkg = _pkgs.shift()?
      let name_with_channel = recover val pkg.name() + "/" + pkg.channel end
      _h.env.out.print("sync -- " + name_with_channel)
      _TestPonyup.exec(
        _h,
        name_with_channel,
        [ "update"; pkg.name(); pkg.channel + "-" + pkg.version
          "--platform=" + pkg.platform()
        ],
        {()(self = recover tag this end)? =>
          _TestPonyup.check_files(_h, name_with_channel, pkg)?
          self.run()
        } val)?
    else
      _h.fail("exec error")
      _h.complete(false)
    end

  be log(level: LogLevel, msg: String) =>
    match level
    | InternalErr | Err =>
      _h.fail(msg)
      _h.env.err.print(msg)
    else
      _h.env.out.print(msg)
    end

  be write(str: String, ansi_color_code: String = "") =>
    _h.env.out.write(str)

primitive _TestPonyup
  fun platform(): String =>
    if Platform.windows() then
      "x86_64-pc-windows-msvc"
    else
      "x86_64-alpine-linux-musl"
    end

  fun ponyup_bin(auth: AmbientAuth): FilePath? =>
    let bin_name =
      ifdef windows then
        "ponyup.exe"
      else
        "ponyup"
      end

    FilePath(FileAuth(auth), "./build")
      .join(if Platform.debug() then "debug" else "release" end)?
      .join(bin_name)?

  fun exec(h: TestHelper, dir: String, args: Array[String] val, cb: {()?} val)
    ?
  =>
    let auth = h.env.root
    let bin = ponyup_bin(auth)?

    h.env.out.print(recover val
      let dbg_str = String
        .>append(bin.path)
        .>append(" --prefix=./.pony_test/")
        .>append(dir)
        .>append(" --verbose")
      for arg in args.values() do
        dbg_str.append(" ")
        dbg_str.append(arg)
      end
      dbg_str
    end)

    let ponyup_monitor = ProcessMonitor(
      StartProcessAuth(auth),
      ApplyReleaseBackpressureAuth(auth),
      object iso is ProcessNotify
        fun stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
          h.log(String.from_array(consume data))

        fun stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
          h.log(String.from_array(consume data))

        fun failed(p: ProcessMonitor, err: ProcessError) =>
          h.fail("ponyup error: " + err.string())
          h.complete(false)

        fun dispose(p: ProcessMonitor, exit: ProcessExitStatus) =>
          if not (exit == Exited(0)) then
            h.fail("ponyup failed with status " + exit.string())
            h.complete(false)
          else
            try
              cb()?
            else
              h.fail("exec callback threw an error")
              h.complete(false)
            end
          end
      end,
      bin,
      recover
        [bin.path; "--prefix=./.pony_test/" + dir; "--verbose"] .> append(args)
      end,
      h.env.vars)

    ponyup_monitor.done_writing()

fun check_files(h: TestHelper, dir: String, pkg: Package) ? =>
  let auth = h.env.root
  let install_path = FilePath(FileAuth(auth), "./.pony_test").join(dir)?.join("ponyup")?
  let bin_path = install_path.join(pkg.string())?.join("bin")?
    .join(pkg.name() + ifdef windows then ".exe" else "" end)?
  h.assert_true(bin_path.exists())
