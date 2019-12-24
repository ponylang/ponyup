use "files"
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
    for name in Packages().values() do
      try
        let pkg = Packages.from_fragments(name, "nightly", "latest", [])?
        test(_TestSync(pkg))
        return // TODO
      end
    end

class _TestSync is UnitTest
  let _pkg: Package

  new iso create(pkg: Package) =>
    _pkg = pkg
    // TODO: add libc

  fun name(): String =>
    "sync " + _pkg.string()

  fun apply(h: TestHelper) ? =>
    let auth = h.env.root as AmbientAuth
    let ponyup_bin =
      FilePath(auth, "./build")?
        .join(if Platform.debug() then "debug" else "release" end)?
        .join("ponyup")?

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
          CheckFiles(h, _pkg)
      end,
      ponyup_bin,
      [ ponyup_bin.path
        "update"; _pkg.name; _pkg.channel + "-" + _pkg.version
        "--prefix=./.pony_test"
      ],
      h.env.vars)

    ponyup_monitor.done_writing()
    h.long_test(10_000_000_000)

primitive CheckFiles
  fun apply(h: TestHelper, pkg: Package) =>
    // h.fail("TODO")
    h.complete(false)
