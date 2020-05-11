use "appdirs"
use "cli"
use "files"
use "term"

actor Main is PonyupNotify
  let _env: Env
  let _default_root: String
  var _verbose: Bool = false
  var _boring: Bool = false

  new create(env: Env) =>
    _env = consume env

    let app_dirs =
      recover val AppDirs(_env.vars, "ponyup" where osx_as_unix = true) end
    _default_root = try app_dirs.user_data_dir()? else "" end
    if _default_root == "" then
      _env.out.print("error: Unable to find user data directory")
      return
    end

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
    let default_prefix: String val =
      _default_root.substring(0, -"/ponyup".size().isize())
    let command =
      match recover val CLI.parse(_env.args, _env.vars, default_prefix) end
      | let c: Command val => c
      | (let exit_code: U8, let msg: String) =>
        if exit_code == 0 then
          _env.out.print(msg)
        else
          log(Err, msg + "\n")
          _env.out.print(CLI.help(default_prefix))
          _env.exitcode(exit_code.i32())
        end
        return
      end

    _verbose = command.option("verbose").bool()
    _boring = command.option("boring").bool()

    var prefix = command.option("prefix").string()
    if prefix == "" then prefix = default_prefix end
    log(Extra, "prefix: " + prefix)

    let ponyup_dir =
      try
        FilePath(auth, prefix + "/ponyup")?
      else
        log(Err, "invalid ponyup prefix: " + prefix)
        return
      end

    if (not ponyup_dir.exists()) and (not ponyup_dir.mkdir()) then
      log(Err, "unable to create root directory: " + ponyup_dir.path)
    end

    let lockfile =
      try
        recover CreateFile(ponyup_dir.join(".lock")?) as File end
      else
        log(Err, "unable to create lockfile (" + ponyup_dir.path + "/.lock)")
        return
      end

    var platform = command.option("platform").string()
    if platform == "" then
      try
        with f = OpenFile(ponyup_dir.join(".platform")?) as File do
          platform = f.lines().next()? .> lstrip() .> rstrip()
        end
      end
    end
    log(Extra, "platform: " + platform)

    let ponyup = Ponyup(_env, auth, ponyup_dir, consume lockfile, this)

    match command.fullname()
    | "ponyup/version" => _env.out .> write("ponyup ") .> print(Version())
    | "ponyup/show" => show(ponyup, command, platform)
    | "ponyup/update" => sync(ponyup, command, platform)
    | "ponyup/select" => select(ponyup, command, platform)
    else
      log(InternalErr, "Unknown command: " + command.fullname())
    end

  be show(ponyup: Ponyup, command: Command val, platform: String) =>
    ponyup.show(
      command.arg("package").string(),
      command.option("local").bool(),
      platform)

  be sync(ponyup: Ponyup, command: Command val, platform: String) =>
    let chan = command.arg("version/channel").string().split("-")
    let pkg =
      try
        Packages.from_fragments(
          command.arg("package").string(),
          chan(0)?,
          try chan(1)? else "latest" end,
          platform.string().split("-"))?
      else
        log(Err, "".join(
          [ "unexpected selection: "
            command.arg("package").string()
            "-"; command.arg("version/channel").string()
            "-"; platform
          ].values()))
        return
      end
    ponyup.sync(pkg)

  be select(ponyup: Ponyup, command: Command val, platform: String) =>
    let chan = command.arg("version").string().split("-")
    let pkg =
      try
        Packages.from_fragments(
          command.arg("package").string(),
          chan(0)?,
          try chan(1)? else "latest" end,
          platform.string().split("-"))?
      else
        log(Err, "".join(
          [ "unexpected selection: "
            command.arg("package").string()
            "-"; command.arg("version").string()
            "-"; platform
          ].values()))
        return
      end
    ponyup.select(pkg)

  be log(level: LogLevel, msg: String) =>
    match level
    | Info | Extra =>
      if (level is Info) or _verbose then
        if level is Extra then
          _env.out.write(colorful(ANSI.grey(), "info: "))
        end
        _env.out.print(msg)
      end
    | Err | InternalErr =>
      _env.exitcode(1)
      var msg' =
        // strip error prefix from CLI package
        if msg.substring(0, 7) == "Error: " then
          msg.substring(7)
        else
          consume msg
        end
      _env.out .> write(colorful(ANSI.bright_red(), "error: ")) .> print(msg')

      if level is InternalErr then
        _env.out
          .> write("Internal error encountered. Please open an issue at ")
          .> print("https://github.com/ponylang/ponyup")
      end
    end

  be write(str: String, ansi_color_code: String = "") =>
    _env.out.write(
      if ansi_color_code == "" then str else colorful(ansi_color_code, str) end)

  fun colorful(ansi_color_code: String, msg: String): String iso^ =>
    "".join(
      [ if not _boring then ansi_color_code else "" end
        msg
        if not _boring then ANSI.reset() else "" end
      ].values())

primitive Info
primitive Extra
primitive Err
primitive InternalErr
type LogLevel is (InternalErr | Err | Info | Extra)
