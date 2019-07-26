use "cli"
use "http"

primitive Info
  fun project_repo_link(): String =>
    "https://github.com/theodus/ponyup"

  fun please_report(): String =>
    "Internal error encountered. Please open an issue at " + project_repo_link()

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = consume env

    if not Platform.linux() then
      _env.err.print("Unsupported platform")
      _env.exitcode(1)
      return
    end

    run_command()

  be run_command() =>
    let command =
      match recover val CLI.parse(_env.args, _env.vars) end
      | let c: Command val => c
      | (let exit_code: U8, let msg: String) =>
        _env.exitcode(exit_code.i32())
        _env.out.print(msg)
        return
      end

    match command.fullname()
    | "ponyup/show" => show(command)
    | "ponyup/update" => update(command)
    else
      _env.out.print("Unknown command: " + command.fullname())
      _env.out.print(Info.please_report())
    end

  be show(command: Command val) =>
    _env.out.print("This currently does absolutely nothing useful.")

  be update(command: Command val) =>
    _env.out.print("This currently does absolutely nothing useful.")
