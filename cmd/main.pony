use "cli"
use "files"

primitive Info
  fun version(): String =>
    "0.0.1"

  fun project_repo_link(): String =>
    "https://github.com/theodus/ponyup"

  fun please_report(): String =>
    "Internal error encountered. Please open an issue at " + project_repo_link()

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = consume env

    if not Platform.linux() then
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
      match recover val CLI.parse(_env.args, _env.vars) end
      | let c: Command val => c
      | (let exit_code: U8, let msg: String) =>
        log.err(msg)
        _env.exitcode(exit_code.i32())
        return
      end

    log = Log(
      _env,
      command.option("verbose").bool(),
      command.option("boring").bool())

    let prefix = command.option("prefix").string()
    log.verbose("prefix: " + prefix)

    match command.fullname()
    | "ponyup/version" => _env.out.print("ponyup " + Info.version())
    | "ponyup/show" => show(log, command)
    | "ponyup/update" => sync(log, command, auth, prefix)
    else
      log.err("Unknown command: " + command.fullname())
      log.info(Info.please_report())
    end

  be show(log: Log, command: Command val) =>
    log.info("This currently does absolutely nothing useful.")

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
      // .> enqueue(source, "stable")

  fun _ponyup_dir(auth: AmbientAuth, prefix: String): FilePath ? =>
    FilePath(auth, prefix + "/ponyup")?
