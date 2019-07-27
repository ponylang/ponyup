use "cli"
use "http"
use "term"

primitive Info
  fun version(): String =>
    "0.0.1"

  fun project_repo_link(): String =>
    "https://github.com/theodus/ponyup"

  fun please_report(): String =>
    "Internal error encountered. Please open an issue at " + project_repo_link()

actor Main
  let _env: Env
  var _boring: Bool = false
  var _verbose: Bool = false
  var _prefix: String = ""

  new create(env: Env) =>
    _env = consume env

    if not Platform.linux() then
      _env.exitcode(1)
      log_err("Unsupported platform")
      return
    end

    run_command()

  be run_command() =>
    let command =
      match recover val CLI.parse(_env.args, _env.vars) end
      | let c: Command val => c
      | (let exit_code: U8, let msg: String) =>
        _env.exitcode(exit_code.i32())
        log_err(msg)
        return
      end

    _boring = command.option("boring").bool()
    _verbose = command.option("verbose").bool()
    _prefix = command.option("prefix").string()

    match command.fullname()
    | "ponyup/version" => log_info("ponyup " + Info.version())
    | "ponyup/show" => show(command)
    | "ponyup/update" => update(command)
    else
      log_err("Unknown command: " + command.fullname())
      log_info(Info.please_report())
    end

  be show(command: Command val) =>
    log_info("This currently does absolutely nothing useful.")

  be update(command: Command val) =>
    let selection = command.arg("version/channel").string()
    log_info("update " + selection)

  fun log_info(msg: String) =>
    _env.out.print(msg)

  fun log_verbose(msg: String) =>
    if _verbose then log_info(msg) end

  fun log_err(msg: String) =>
    var msg' = consume msg
    if msg'.substring(0, 7) == "Error: " then
      msg' = msg'.substring(7)
    end
    _env.out.print(colorful(ANSI.bright_red(), "error: ") + msg')

  fun colorful(ansi_code: String, msg: String): String =>
    "".join(
      [ if not _boring then ansi_code else "" end
        msg
        if not _boring then ANSI.reset() else "" end
      ].values())
