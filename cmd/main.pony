use "cli"
use "files"
use "process"

primitive Info
  fun version(): String =>
    Version()

  fun project_repo_link(): String =>
    "https://github.com/ponylang/ponyup"

  fun please_report(): String =>
    "Internal error encountered. Please open an issue at " + project_repo_link()

actor Main
  let _env: Env
  let _default_prefix: String

  new create(env: Env) =>
    _env = consume env

    var home = ""
    for v in _env.vars.values() do
      if v.substring(0, 5) == "HOME=" then
        home = v.substring(5)
        break
      end
    end
    _default_prefix = home + "/.pony"

    if not Platform.posix() then
      _env.exitcode(1)
      _env.out.print("error: Unsupported platform")
      return
    end

    let auth =
      try
        _env.root as AmbientAuth
      else
        _env.exitcode(1)
        _env.out.print("error: environment does not have ambient authority")
        return
      end

    run_command(auth)

  be run_command(auth: AmbientAuth) =>
    var log = Log(_env)

    let command =
      match recover val CLI.parse(_env.args, _env.vars, _default_prefix) end
      | let c: Command val => c
      | (let exit_code: U8, let msg: String) =>
        if exit_code == 0 then
          log.print(msg)
        else
          log.err(msg + "\n")
          log.print(CLI.help(_default_prefix))
          _env.exitcode(exit_code.i32())
        end
        return
      end

    log = Log(
      _env,
      command.option("verbose").bool(),
      command.option("boring").bool())

    var prefix = command.option("prefix").string()
    if prefix == "" then prefix = _default_prefix end
    log.verbose("prefix: " + prefix)

    match command.fullname()
    | "ponyup/version" => log.print("ponyup " + Info.version())
    | "ponyup/show" => show(log, command, auth, prefix)
    | "ponyup/update" => sync(log, command, auth, prefix)
    else
      log.err("Unknown command: " + command.fullname())
      log.info(Info.please_report())
    end

  be show(log: Log, command: Command val, auth: AmbientAuth, prefix: String) =>
    let selected_ponyc_path =
      try
        _ponyup_dir(auth, prefix)?.join("bin/ponyc")?
      else
        log.err("invalid path: " + prefix + "/bin/ponyc")
        return
      end
    let ponyc_monitor = ProcessMonitor(
      auth,
      auth,
      object iso is ProcessNotify
        fun stdout(p: ProcessMonitor, data: Array[U8] iso) =>
          log.print(String.from_iso_array(consume data))

        fun failed(p: ProcessMonitor, err: ProcessError) =>
          log.err("Unable to execute " + selected_ponyc_path.path)

        fun dispose(p: ProcessMonitor, exit: I32) =>
          if exit != 0 then failed(p, WaitpidError) end
      end,
      selected_ponyc_path,
      ["ponyc"; "--version"],
      _env.vars)

    ponyc_monitor.done_writing()

  be sync(log: Log, command: Command val, auth: AmbientAuth, prefix: String) =>
    let source =
      match command.arg("version/channel").string()
      | "nightly" => Nightly()
      | let str: String =>
        if str.substring(0, 8) == "nightly-" then
          Nightly(str.substring(8))
        else
          log.err("unexpected selection: " + str)
          return
        end
      end

    log.info("updating " + source.string())

    let ponyup_dir =
      try
        _ponyup_dir(auth, prefix)?
      else
        log.err("invalid ponyup prefix: " + prefix)
        return
      end

    let sync_monitor = SyncMonitor(_env, auth, log, ponyup_dir)
    sync_monitor
      .> enqueue(source, "ponyc")
      .> enqueue(source, "corral")
      .> enqueue(source, "stable")

  fun _ponyup_dir(auth: AmbientAuth, prefix: String): FilePath ? =>
    FilePath(auth, prefix + "/ponyup")?
