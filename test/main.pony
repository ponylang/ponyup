use "backpressure"
use "files"
use "json"
use "net"
use "pony_test"
use "process"
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

class _TestParsePlatform is UnitTest
  fun name(): String =>
    "parse platform"

  fun apply(h: TestHelper) ? =>
    h.assert_no_error(
      {()? => Packages.from_string("?-?-?-" + _TestPonyup.platform(h))? })

    let tests =
      [ as (String, ((CPU, OS, Distro) | None)):
        ("ponyc-?-?-x86_64-unknown-linux-ubuntu22.04", (AMD64, Linux, "ubuntu22.04"))
        ("ponyc-?-?-x64-linux-ubuntu22.04", (AMD64, Linux, "ubuntu22.04"))
        ("ponyc-x86_64-pc-linux-ubuntu24.04", (AMD64, Linux, "ubuntu24.04"))
        ("?-?-?-amd64-linux-ubuntu22.04", (AMD64, Linux, None))
        ("ponyc-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, "musl"))
        ("?-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, None))
        ("ponyc-?-?-x86_64-apple-darwin", (AMD64, Darwin, None))
        ("?-?-?-darwin", (AMD64, Darwin, None))
        ( "ponyc-?-?-musl"
        , (AMD64, Packages.platform_os()?, Packages.platform_distro("musl"))
        )
        ("?-?-?-musl", (AMD64, Packages.platform_os()?, None))
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
  let _pkg_name: String
  let _channel: String

  new iso create(pkg_name: String, channel: String) =>
    _pkg_name = pkg_name
    _channel = channel

  fun name(): String =>
    "sync - " + _pkg_name + "-" + _channel

  fun apply(h: TestHelper) =>
    _SyncTester(h, h.env.root, _pkg_name, _channel)
    h.long_test(120_000_000_000)

class _TestSelect is UnitTest
  let _ponyc_versions: Array[String] val =
    if Platform.osx() and Platform.arm() then
      ["release-0.55.0"; "release-0.55.1"]
    else
      ["release-0.58.0"; "release-0.58.1"]
    end

  fun name(): String =>
    "select"

  fun apply(h: TestHelper) ? =>
    let platform = _TestPonyup.platform(h)
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
          h, "select", ["select"; "ponyc" ; _ponyc_versions(0)?],
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

actor _SyncTester is PonyupNotify
  let _h: TestHelper
  let _auth: AmbientAuth
  let _pkg_name: String
  embed _pkgs: Array[Package] = []

  new create(
    h: TestHelper,
    auth: AmbientAuth,
    pkg_name: String,
    channel: String)
  =>
    _h = h
    _auth = auth
    _pkg_name = pkg_name

    let platform = _TestPonyup.platform(h)
    let http_get = HTTPGet(NetAuth(_auth), this)
    try
      let pkg = Packages.from_fragments(
        _pkg_name, channel, "latest", platform.split("-"))?
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
      let name_with_channel = recover val pkg.name + "/" + pkg.channel end
      _h.env.out.print("sync -- " + name_with_channel)
      _TestPonyup.exec(
        _h,
        name_with_channel,
        [ "update"; pkg.name; pkg.channel + "-" + pkg.version
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
  fun platform(h: TestHelper): String =>
    let env_key = "PONYUP_PLATFORM"
    for v in h.env.vars.values() do
      if not v.contains(env_key) then continue end
      return v.substring(env_key.size().isize() + 1)
    end
    h.log(env_key + " not set")
    h.fail()
    "?"

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
    .join(pkg.name + ifdef windows then ".exe" else "" end)?
  h.assert_true(bin_path.exists())
