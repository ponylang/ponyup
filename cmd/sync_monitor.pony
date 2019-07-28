use "files"
use "http"
use "process"

actor SyncMonitor
  let _env: Env
  let _auth: AmbientAuth
  let _log: Log
  let _ponyup_dir: FilePath

  let _q: Array[(Source, String)] = []

  new create(env: Env, auth: AmbientAuth, log: Log, ponyup_dir: FilePath) =>
    (_env, _auth, _log, _ponyup_dir) = (env, auth, log, ponyup_dir)

  be enqueue(source: Source, package: String) =>
    _q.push((source, package))
    if _q.size() == 1 then _next() end

  be _done() =>
    try _q.shift()? end
    _next()

  be _next() =>
    (let source, let package) = try _q(0)? else return end

    _log.info("syncing updates from " + source.url())
    let query_string = source.url() + source.query(package)
    _log.verbose("query url: " + query_string)

    let self = recover tag this end
    if not
      _http_get(
        query_string,
        {(_)(self, source, package) =>
          QueryHandler({(res) => self._sync_response(source, package, res) })
        })
    then
      _log.info(Info.please_report())
    end

  be _sync_response(source: Source, package: String, payload: Payload val) =>
    let res = recover String(try payload.body_size() as USize else 0 end) end
    try
      for chunk in payload.body()?.values() do
        match chunk
        | let s: String => res.append(s)
        | let bs: Array[U8] val => res.append(String.from_array(bs))
        end
      end
    else
      _log.err("unable to read response body")
      return
    end

    let sync_info =
      try
        source.parse_sync(consume res)?
      else
        _log.err("requested pony version was not found")
        return
      end

    let source_path =
      match _update_path(source, sync_info, sync_info.version)
      | let p: FilePath => p
      | None =>
        _log.info(source.string() + " is up to date")
        return
      end

    _log.verbose("path: " + source_path.path)
    _log.info("pulling " + sync_info.version)
    _log.verbose("dl_url: " + sync_info.download_url)

    if not _ponyup_dir.mkdir() then
      _log.err("unable to mkdir: " + _ponyup_dir.path)
      return
    end

    let ld_file_path = source_path.path + ".tar.gz"
    let ld_file =
      try
        FilePath(_auth, ld_file_path)?
      else
        _log.err("invalid file path: " + ld_file_path)
        return
      end

    let self = recover tag this end
    let dump = DLDump(
      _env.out,
      ld_file,
      {(f, c) => self._dl_complete(sync_info, f, c)})

    _http_get(sync_info.download_url, {(_)(dump) => DLHandler(dump) })

  be _dl_complete(sync_info: SyncInfo, file_path: FilePath, checksum: String)
  =>
    if checksum != sync_info.checksum then
      _log.err("checksum failed")
      _log.info("    expected: " + sync_info.checksum)
      _log.info("  calculated: " + checksum)
      if not file_path.remove() then
        _log.err("unable to remove file: " + file_path.path)
      end
      return
    end
    _log.verbose("checksum ok: " + checksum)

    let tar_monitor = ProcessMonitor(
      _auth,
      _auth,
      object iso is ProcessNotify
        let self: SyncMonitor = this

        fun failed(p: ProcessMonitor, err: ProcessError) =>
          self._extract_failure()

        fun dispose(p: ProcessMonitor, exit: I32) =>
          if exit != 0 then self._extract_failure() end
          file_path.remove()
          self._done()
      end,
      try FilePath(_auth, "/bin/tar")? else return end,
      ["tar"; "-C"; _ponyup_dir.path; "-xzf"; file_path.path],
      _env.vars)

    tar_monitor.done_writing()

  be _extract_failure() =>
    _log.err("failed to extract archive")

  fun _http_get(url_string: String, hf: HandlerFactory val): Bool =>
    let client = HTTPClient(_auth where keepalive_timeout_secs = 10)
    let url =
      try
        URL.valid(url_string)?
      else
        _log.err("invalid url: " + url_string)
        return false
      end

    let req = Payload.request("GET", url)
    req("User-Agent") = "ponyup"
    try client(consume req, hf)?
    else _log.err("server unreachable, please try again later")
    end
    true

  fun _update_path(source: Source, sync_info: SyncInfo, package: String)
    : (FilePath | None)
  =>
    try
      let source_dir =
        _ponyup_dir.join(source.name() + "-" + sync_info.version)?
      let check_path = source_dir.join(source.check_path(package))?
      if not check_path.exists() then source_dir end
    end
