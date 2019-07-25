use "cli"

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = consume env

    if not Platform.linux() then
      _env.err.print("Unsupported platform")
      _env.exitcode(1)
      return
    end

    let cmd =
      match CLI.parse(_env.args, _env.vars)
      | (let _: U8, let c: Command) => c
      | (let exit_code: U8, let msg: String) =>
        _env.exitcode(exit_code.i32())
        _env.out.print(msg)
        return
      end

    _env.out.print("This currently does absolutely nothing useful.")
