use "cli"
use "collections"
use "files"
use "http"
use "term"

actor Ponyup
  let _out: OutStream
  let _auth: AmbientAuth
  let _env: Env

  var _boring: Bool = false
  var _verbose: Bool = false
  var _prefix: String = ""

  new create(out: OutStream, auth: AmbientAuth, env: Env) =>
    _out = out
    _auth = auth
    _env = env

    run_command()

  be run_command() =>
    let command =
      match recover val CLI.parse(_env.args, _env.vars) end
      | let c: Command val => c
      | (let exit_code: U8, let msg: String) =>
        log_err(msg)
        _env.exitcode(exit_code.i32())
        return
      end

    _boring = command.option("boring").bool()
    _verbose = command.option("verbose").bool()
    _prefix = command.option("prefix").string()
    log_verbose("prefix: " + _prefix)

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
    let source =
      match command.arg("version/channel").string()
      | "nightly" => Nightly()
      | let str: String =>
        if str.substring(0, 8) == "nightly-" then
          Nightly(str.substring(8))
        else
          log_err("unexpected selection: " + str)
          return
        end
      end

    log_info("updating ponyc " + source.string())
    log_info("syncing updates from " + source.url())
    let query_string = source.url() + source.query()
    log_verbose("query url: " + query_string)

    let self = recover tag this end
    if not
      http_get(
        query_string,
        {(_)(self, source) =>
          QueryHandler({(res) => self.sync_response(source, res) })
        })
    then
      log_info(Info.please_report())
    end

  be sync_response(source: Source, payload: Payload val) =>
    let res = recover String(try payload.body_size() as USize else 0 end) end
    try
      for chunk in payload.body()?.values() do
        match chunk
        | let s: String => res.append(s)
        | let bs: Array[U8] val => res.append(String.from_array(bs))
        end
      end
    else
      log_err("unable to read response body")
      return
    end

    let sync_info =
      try
        source.parse_sync(consume res)?
      else
        log_err("requested pony version was not found")
        return
      end

    let dir =
      match update_path(source, sync_info)
      | let fp: FilePath => fp
      | None =>
        log_info(source.string() + " is up to date")
        return
      end

    log_verbose("path: " + dir.path)
    log_info("pulling " + sync_info.version)
    log_verbose("dl_url: " + sync_info.download_url)

    if not dir.mkdir() then
      log_err("unable to mkdir: " + dir.path)
      return
    end

    let ld_file_path = dir.path + ".tar.gz"
    let ld_file =
      try
        FilePath(_auth, ld_file_path)?
      else
        log_err("invalid file path: " + ld_file_path)
        return
      end

    let self = recover tag this end
    let dump = DLDump(
      _out,
      ld_file,
      {(f, c) => self.dl_complete(dir, sync_info, f, c)})

    http_get(sync_info.download_url, {(_)(dump) => DLHandler(dump) })

  be dl_complete(
    dir: FilePath,
    sync_info: SyncInfo,
    file_path: FilePath,
    checksum: String)
  =>
    if checksum != sync_info.checksum then
      log_err("checksum failed")
      log_info("    expected: " + sync_info.checksum)
      log_info("  calculated: " + checksum)
      if not file_path.remove() then
        log_err("unable to remove file: " + file_path.path)
      end
      return
    end
    log_verbose("checksum ok: " + checksum)

    log_err("TODO: extract archive")

  fun source_dir(source: Source, version: String): FilePath ? =>
    FilePath(_auth, _prefix + "/ponyup/" + source.name() + "-" + version)?

  fun update_path(source: Source, sync_info: SyncInfo): (FilePath | None) =>
    log_verbose("source version: " + sync_info.version)
    try
      let dir = source_dir(source, sync_info.version)?
      if not dir.exists() then dir end
    end

  fun http_get(url_string: String, hf: HandlerFactory val): Bool =>
    let client = HTTPClient(_auth where keepalive_timeout_secs = 10)
    let url =
      try
        URL.valid(url_string)?
      else
        log_err("invalid url: " + url_string)
        return false
      end

    let req = Payload.request("GET", url)
    req("User-Agent") = "ponyup"
    try client(consume req, hf)?
    else log_err("server unreachable, please try again later")
    end
    true

  fun log_info(msg: String) =>
    _out.write("info: ")
    _out.print(msg)

  fun log_verbose(msg: String) =>
    if _verbose then log_info(msg) end

  fun log_err(msg: String) =>
    _env.exitcode(1)
    var msg' = consume msg
    if msg'.substring(0, 7) == "Error: " then
      msg' = msg'.substring(7)
    end
    _out.print(colorful(ANSI.bright_red(), "error: ") + msg')

  fun colorful(ansi_code: String, msg: String): String =>
    "".join(
      [ if not _boring then ansi_code else "" end
        msg
        if not _boring then ANSI.reset() else "" end
      ].values())
