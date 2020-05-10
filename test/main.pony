use "files"
use "json"
use "net"
use "ponytest"
use "process"
use "../cmd"

actor Main is TestList
  new create(env: Env) =>
    try
      let test_dir = FilePath(env.root as AmbientAuth, "./.pony_test")?
      if test_dir.exists() then test_dir.remove() end
    end
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestParsePlatform)

    for package in Packages().values() do
      test(_TestSync(package))
    end
    test(_TestSelect)

class _TestParsePlatform is UnitTest
  fun name(): String =>
    "parse platform"

  fun apply(h: TestHelper) ? =>
    let tests =
      [ as (String, (CPU, OS, Libc)):
        ("ponyc-?-?-x86_64-unknown-linux-gnu", (AMD64, Linux, Glibc))
        ("ponyc-?-?-x64-linux-gnu", (AMD64, Linux, Glibc))
        ("?-?-?-amd64-linux-gnu", (AMD64, Linux, None))
        ("ponyc-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, Musl))
        ("?-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, None))
        ("ponyc-?-?-x86_64-apple-darwin", (AMD64, Darwin, None))
        ("?-?-?-darwin", (AMD64, Darwin, None))
        ( "ponyc-?-?-musl"
        , ( AMD64
          , if Platform.osx() then Darwin else Linux end
          , if Platform.osx() then None else Musl end ) )
        ( "?-?-?-musl"
        , (AMD64, if Platform.osx() then Darwin else Linux end, None) )
      ]
    for (input, (cpu, os, libc)) in tests.values() do
      let pkg = Packages.from_string(input)?
      h.log(pkg.string())
      h.assert_is[CPU](pkg.cpu, cpu)
      h.assert_is[OS](pkg.os, os)
      h.assert_is[Libc](pkg.libc, libc)
    end

class _TestSync is UnitTest
  let _pkg_name: String

  new iso create(pkg_name: String) =>
    _pkg_name = pkg_name

  fun name(): String =>
    "sync - " + _pkg_name

  fun apply(h: TestHelper) ? =>
    let auth = h.env.root as AmbientAuth
    _SyncTester(h, auth, _pkg_name)
    h.long_test(30_000_000_000)

class _TestSelect is UnitTest
  let _ponyc_versions: Array[String] val =
    ["release-0.33.2"; "release-0.34.0"]

  fun name(): String =>
    "select"

  fun apply(h: TestHelper) ? =>
    let platform = _TestPonyup.platform(h.env.vars)
    let install_args: {(String): Array[String] val} val =
      {(v) => ["update"; "ponyc"; v; "--platform=" + platform] }

    let link =
      FilePath(
        h.env.root as AmbientAuth,
        "./.pony_test/select/ponyup/bin/ponyc")?

    let check =
      {()? =>
        h.assert_true(link.canonical()?.path.contains(_ponyc_versions(0)?))
        _TestPonyup.exec(
          h, "select", ["select"; "ponyc" ; _ponyc_versions(1)?],
          {()? =>
            h.assert_true(
              link.canonical()?.path.contains(_ponyc_versions(1)?))
            h.complete(true)
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

    h.long_test(30_000_000_000)

actor _SyncTester is PonyupNotify
  let _h: TestHelper
  let _auth: AmbientAuth
  let _pkg_name: String
  embed _pkgs: Array[Package] = []

  new create(h: TestHelper, auth: AmbientAuth, pkg_name: String) =>
    _h = h
    _auth = auth
    _pkg_name = pkg_name

    let platform = _TestPonyup.platform(h.env.vars)
    let http_get = HTTPGet(NetAuth(_auth), this)
    for channel in ["nightly"; "release"].values() do
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
      _h.env.out.print("sync -- " + pkg.string())
      _TestPonyup.exec(
        _h,
        pkg.name,
        [ "update"; pkg.name; pkg.channel + "-" + pkg.version
          "--platform=" + pkg.platform()
        ],
        {()(self = recover tag this end)? =>
          _TestPonyup.check_files(_h, pkg.name, pkg)?
          self.run()
        } val)?
    else
      _h.fail("exec error")
      _h.complete(false)
    end

  be log(level: LogLevel, msg: String) =>
    _h.env.out.print(msg)

  be write(str: String, ansi_color_code: String = "") =>
    _h.env.out.write(str)

primitive _TestPonyup
  fun platform(vars: Array[String] box): String =>
    let key = "PONYUP_PLATFORM"
    var platform' = ""
    for v in vars.values() do
      if not v.contains(key) then continue end
      platform' = v.substring(key.size().isize() + 1)
      break
    end
    platform'

  fun ponyup_bin(auth: AmbientAuth): FilePath? =>
    FilePath(auth, "./build")?
      .join(if Platform.debug() then "debug" else "release" end)?
      .join("ponyup")?

  fun exec(h: TestHelper, dir: String, args: Array[String] val, cb: {()?} val)
    ?
  =>
    let auth = h.env.root as AmbientAuth
    let bin = ponyup_bin(auth)?
    let ponyup_monitor = ProcessMonitor(
      auth,
      auth,
      object iso is ProcessNotify
        fun stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
          h.log(String.from_array(consume data))

        fun stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
          h.log(String.from_array(consume data))

        fun failed(p: ProcessMonitor, err: ProcessError) =>
          h.fail("ponyup error")

        fun dispose(p: ProcessMonitor, exit: ProcessExitStatus) =>
          h.assert_eq[ProcessExitStatus](exit, Exited(0))
          try
            cb()?
          else
            h.fail("exec callback")
            h.complete(false)
          end
      end,
      bin,
      recover
        [bin.path; "--prefix=./.pony_test/" + dir; "--verbose"] .> append(args)
      end,
      h.env.vars)

    ponyup_monitor.done_writing()

fun check_files(h: TestHelper, dir: String, pkg: Package) ? =>
  let auth = h.env.root as AmbientAuth
  let install_path = FilePath(auth, "./.pony_test")?.join(dir)?.join("ponyup")?
  let bin_path = install_path.join(pkg.string())?.join("bin")?.join(pkg.name)?
  h.assert_true(bin_path.exists())
