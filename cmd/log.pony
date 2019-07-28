use "term"

actor Log
  let _env: Env
  let _verbose: Bool
  let _boring: Bool

  new create(env': Env, verbose': Bool = false, boring': Bool = false) =>
   (_env, _verbose, _boring) = (env', verbose', boring')

  be info(msg: String) =>
    _env.out.write("info: ")
    _env.out.print(msg)

  be verbose(msg: String) =>
    if _verbose then info(msg) end

  be err(msg: String) =>
    _env.exitcode(1)
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
