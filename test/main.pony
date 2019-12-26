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
    for package in Packages().values() do
      test(_TestSync(package))
    end

class _TestSync is UnitTest
  let _pkg_name: String

  new iso create(pkg_name: String) =>
    _pkg_name = pkg_name

  fun name(): String =>
    "sync - " + _pkg_name

  fun apply(h: TestHelper) ? =>
    let auth = h.env.root as AmbientAuth
    let ponyup_bin =
      FilePath(auth, "./build")?
        .join(if Platform.debug() then "debug" else "release" end)?
        .join("ponyup")?

    _SyncTester(h, auth, ponyup_bin, _pkg_name)
    h.long_test(20_000_000_000)

actor _SyncTester is PonyupNotify
  let _h: TestHelper
  let _auth: AmbientAuth
  let _pkg_name: String
  let _ponyup_bin: FilePath
  embed _pkgs: Array[Package] = []

  new create(
    h: TestHelper,
    auth: AmbientAuth,
    ponyup_bin: FilePath,
    pkg_name: String)
  =>
    _h = h
    _auth = auth
    _ponyup_bin = ponyup_bin
    _pkg_name = pkg_name

    let http_get = HTTPGet(NetAuth(_auth), this)
    for channel in ["nightly"; "release"].values() do
      try
        // TODO: specify libc
        let pkg = Packages.from_fragments(_pkg_name, channel, "latest", [])?
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
    if _pkgs.size() >= 3 then run() end

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
        _auth,
        pkg,
        [ _ponyup_bin.path
          "update"; pkg.name; pkg.channel + "-" + pkg.version
          "--verbose"
          "--platform=" + pkg.platform()
        ],
        {()(self = recover tag this end) => self.check(pkg) } val)?
    else
      _h.fail("exec error")
      _h.complete(false)
    end

  be check(pkg: Package) =>
    try
      _TestPonyup.check_files(_h, _auth, pkg)?
      run()
    else
      _h.fail(pkg.string())
      _h.complete(false)
    end

  be log(level: LogLevel, msg: String) =>
    _h.env.out.print(msg)

  be write(str: String, ansi_color_code: String = "") =>
    _h.env.out.write(str)

primitive _TestPonyup
  fun prefix(pkg: Package): String =>
    "./.pony_test/" + pkg.name

  fun exec(
    h: TestHelper,
    auth: AmbientAuth,
    pkg: Package,
    args: Array[String] val,
    cb: {()} val) ?
  =>
    let ponyup_bin = FilePath(auth, args(0)?)?
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

        fun dispose(p: ProcessMonitor, exit: I32) =>
          h.assert_eq[I32](exit, 0)
          cb()
      end,
      ponyup_bin,
      recover args.clone() .> insert(1, "--prefix=" + prefix(pkg))? end,
      h.env.vars)

    ponyup_monitor.done_writing()

fun check_files(h: TestHelper, auth: AmbientAuth, pkg: Package) ? =>
  let install_path = FilePath(auth, prefix(pkg))?.join("ponyup")?
  let bin_path = install_path.join(pkg.string())?.join("bin")?.join(pkg.name)?
  h.assert_true(bin_path.exists())
