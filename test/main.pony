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
    h.assert_no_error(
      {()? => Packages.from_string("?-?-" + _TestPonyup.platform(h))? })

    let tests =
      [ as (String, ((CPU, OS, Distro) | None)):
        ("ponyc-?-?-x86_64-unknown-linux-gnu", (AMD64, Linux, "gnu"))
        ("ponyc-?-?-x64-linux-gnu", (AMD64, Linux, "gnu"))
        ("ponyc-x86_64-pc-linux-ubuntu18.04", (AMD64, Linux, "ubuntu18.04"))
        ("?-?-?-amd64-linux-gnu", (AMD64, Linux, None))
        ("ponyc-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, "musl"))
        ("?-?-?-x86_64-alpine-linux-musl", (AMD64, Linux, None))
        ("ponyc-?-?-x86_64-apple-darwin", (AMD64, Darwin, None))
        ("?-?-?-x86_64-freebsd", (AMD64, FreeBSD, None))
        ("ponyc-?-?-x86_64-freebsd-12.2", (AMD64, FreeBSD, "12.2"))
        ("?-?-?-darwin", (AMD64, Darwin, None))
        ( "ponyc-?-?-musl"
        , (AMD64, Packages.platform_os()?, Packages.platform_distro("musl"))
        )
        ("?-?-?-musl", (AMD64, Packages.platform_os()?, None))
        ("ponyc-?-?-x86_64-freebsd", None)
        ("ponyc-?-?-x86_64-linux", None)
        ("ponyc-?-?-x86_64-darwin", (AMD64, Darwin, None))
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
    ["release-0.41.1"; "release-0.41.2"]

  fun name(): String =>
    "select"

  fun apply(h: TestHelper) ? =>
    let platform = _TestPonyup.platform(h)
    let install_args: {(String): Array[String] val} val =
      {(v) => ["update"; "ponyc"; v; "--platform=" + platform] }

    let link =
      FilePath(
        h.env.root as AmbientAuth,
        "./.pony_test/select/ponyup/bin/ponyc")?

    let check =
      {()? =>
        h.assert_true(link.canonical()?.path.contains(_ponyc_versions(1)?))
        _TestPonyup.exec(
          h, "select", ["select"; "ponyc" ; _ponyc_versions(0)?],
          {()? =>
            h.assert_true(
              link.canonical()?.path.contains(_ponyc_versions(0)?))
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

    let platform = _TestPonyup.platform(h)
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
