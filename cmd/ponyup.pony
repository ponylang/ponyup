use "collections"
use "files"
use "http"
use "process"

/*
 Main      Ponyup           HTTPSession       ProcessMonitor
  | sync     |                   |                  |
  | -------> | (http_get)        |                  |
  |          | ----------------> |                  |
  |          |    query_response |                  |
  |          | <---------------- |                  |
  |          | (http_get)        |                  |
  |          | ----------------> |                  |
  |          |       dl_complete |                  |
  |          | <---------------- |                  |
  |          | (extract_archive)                    |
  |          | -----------------------------------> |
  |          |                     extract_complete |
  |          | <----------------------------------- |
  |          | select            |                  |
  |          | - - - -.          |                  |
  |          | <- - - '          |                  |
*/

actor Ponyup
  let _notify: PonyupNotify
  let _env: Env
  let _auth: AmbientAuth
  let _root: FilePath
  let _lockfile: LockFile

  new create(
    env: Env,
    auth: AmbientAuth,
    root: FilePath,
    lockfile: File iso,
    notify: PonyupNotify)
  =>
    _notify = notify
    _env = env
    _auth = auth
    _root = root
    _lockfile = LockFile(consume lockfile)

  be sync(pkg: Package) =>
    try
      _lockfile.parse()?
    else
      _notify.log(Err, _lockfile.corrupt())
      return
    end

    if not Packages().contains(pkg.name(), {(a, b) => a == b }) then
      _notify.log(Err, "unknown package: " + pkg.name())
      return
    end

    if _lockfile.contains(pkg) then
      _notify.log(Info, pkg.string() + " is up to date")
      return
    end

    _notify.log(Info, "updating " + pkg.string())
    _notify.log(Info, "syncing updates from " + pkg.source_url())
    let query_string = pkg.source_url() + pkg.query()
    _notify.log(Extra, "query url: " + query_string)

    http_get(
      query_string,
      {(_)(self = recover tag this end, pkg) =>
        QueryHandler(_notify, {(res) => self.query_response(pkg, res) })
      })

  be query_response(pkg: Package, payload: Payload val) =>
    let res = recover String(try payload.body_size() as USize else 0 end) end
    try
      for chunk in payload.body()?.values() do
        match chunk
        | let s: String => res.append(s)
        | let bs: Array[U8] val => res.append(String.from_array(bs))
        end
      end
    else
      _notify.log(Err, "unable to read response body")
      return
    end

    let sync_info =
      try
        pkg.parse_sync(consume res)?
      else
        _notify.log(Err, "".join(
          [ "requested package, "; pkg; ", was not found"
          ].values()))
        return
      end

    let pkg' = (consume pkg).update_version(sync_info.version)

    if _lockfile.contains(pkg') then
      _notify.log(Info, pkg'.string() + " is up to date")
      return
    end

    (let install_path, let dl_path) =
      try
        let p = _root.join(pkg'.string())?
        (p, FilePath(_auth, p.path + ".tar.gz")?)
      else
        _notify.log(Err, "invalid path: " + _root.path + "/" + pkg'.string())
        return
      end
    _notify.log(Info, "pulling " + sync_info.version)
    _notify.log(Extra, "download url: " + sync_info.download_url)
    _notify.log(Extra, "install path: " + install_path.path)

    if (not _root.exists()) and (not _root.mkdir()) then
      _notify.log(Err, "unable to create directory: " + _root.path)
      return
    end

    let dump = DLDump(
      _notify,
      dl_path,
      {(checksum)(self = recover tag this end) =>
        self.dl_complete(
          pkg', install_path, dl_path, sync_info.checksum, checksum)
      })

    http_get(sync_info.download_url, {(_)(dump) => DLHandler(dump) })

  be dl_complete(
    pkg: Package,
    install_path: FilePath,
    dl_path: FilePath,
    server_checksum: String,
    client_checksum: String)
  =>
    if client_checksum != server_checksum then
      _notify.log(Err, "checksum failed")
      _notify.log(Info, "    expected: " + server_checksum)
      _notify.log(Info, "  calculated: " + client_checksum)
      if not dl_path.remove() then
        _notify.log(Err, "unable to remove file: " + dl_path.path)
      end
      return
    end
    _notify.log(Extra, "checksum ok: " + client_checksum)

    install_path.mkdir()
    extract_archive(pkg, dl_path, install_path)

  be extract_complete(
    pkg: Package,
    dl_path: FilePath,
    install_path: FilePath)
  =>
    dl_path.remove()
    _lockfile.add_package(pkg)
    if _lockfile.selection(pkg.name()) is None then
      select(pkg)
    else
      _lockfile.dispose()
    end

  be select(pkg: Package) =>
    try
      _lockfile.parse()?
    else
      _notify.log(Err, _lockfile.corrupt())
      return
    end

    _notify.log(Info, " ".join(
      [ "selecting"; pkg; "as default for"; pkg.name()
      ].values()))

    try
      _lockfile.select(pkg)?
    else
      _notify.log(Err,
        "cannot select package " + pkg.string() + ", try installing it first")
      return
    end

    let pkg_dir =
      try
        _root.join(pkg.string())?
      else
        _notify.log(InternalErr, "")
        return
      end

    let link_rel: String = "/".join(["bin"; pkg.name()].values())
    let bin_rel: String = "/".join([pkg.string(); link_rel].values())
    try
      let bin_path = _root.join(bin_rel)?
      _notify.log(Info, " bin: " + bin_path.path)

      let link_dir = _root.join("bin")?
      if not link_dir.exists() then link_dir.mkdir() end

      let link_path = link_dir.join(pkg.name())?
      _notify.log(Info, "link: " + link_path.path)

      if link_path.exists() then link_path.remove() end
      if not bin_path.symlink(link_path) then error end
    else
      _notify.log(Err, "failed to create symbolic link")
      return
    end
    _lockfile.dispose()

  fun http_get(url_string: String, hf: HandlerFactory val) =>
    let client = HTTPClient(_auth where keepalive_timeout_secs = 10)
    let url =
      try
        URL.valid(url_string)?
      else
        _notify.log(InternalErr, "invalid url: " + url_string)
        return
      end

    let req = Payload.request("GET", url)
    req("User-Agent") = "ponyup"
    try
      client(consume req, hf)?
    else
      _notify.log(Err, "server unreachable, please try again later")
    end

  fun ref extract_archive(
    pkg: Package,
    src_path: FilePath,
    dest_path: FilePath)
  =>
    let tar_path =
      try
        find_tar()?
      else
        _notify.log(Err, "unable to find tar executable")
        return
      end

    let tar_monitor = ProcessMonitor(
      _auth,
      _auth,
      object iso is ProcessNotify
        let self: Ponyup = this

        fun failed(p: ProcessMonitor, err: ProcessError) =>
          _notify.log(Err, "failed to extract archive")

        fun dispose(p: ProcessMonitor, exit: I32) =>
          if exit != 0 then _notify.log(Err, "failed to extract archive") end
          self.extract_complete(pkg, src_path, dest_path)
      end,
      tar_path,
      [ "tar"; "-xzf"; src_path.path
        "-C"; dest_path.path; "--strip-components"; "1"
      ],
      _env.vars)

    tar_monitor.done_writing()

  fun find_tar(): FilePath ? =>
    for p in ["/usr/bin/tar"; "/bin/tar"].values() do
      let p' = FilePath(_auth, p)?
      if p'.exists() then return p' end
    end
    error

class LockFileEntry
  embed packages: Array[Package] = []
  var selection: USize = -1

  fun string(): String iso^ =>
    let str = recover String end
    for (i, p) in packages.pairs() do
      str
        .> append(" ".join(
          [ p; if i == selection then "*" else "" end
          ].values()))
        .> append("\n")
    end
    str

class LockFile
  let _file: File
  embed _entries: Map[String, LockFileEntry] = Map[String, LockFileEntry]

  new create(file: File) =>
    _file = file

  fun ref parse() ? =>
    if _entries.size() > 0 then return end
    for line in _file.lines() do
      let fields = line.split(" ")
      if fields.size() == 0 then continue end
      let pkg = Packages.from_string(fields(0)?)?
      let selected = try fields(1)? == "*" else false end

      let entry = _entries.get_or_else(pkg.name(), LockFileEntry)
      if selected then
        entry.selection = entry.packages.size()
      end
      entry.packages.push(pkg)
      _entries(pkg.name()) = entry
    end

  fun contains(pkg: Package): Bool =>
    let v =
      match pkg.version()
      | let v: String => v
      | None => return false
      end
    let entry = _entries.get_or_else(pkg.name(), LockFileEntry)
    entry.packages.contains(pkg, {(a, b) => a.string() == b.string() })

  fun selection(pkg_name: String): (Package | None) =>
    try
      let entry = _entries(pkg_name)?
      entry.packages(entry.selection)?
    end

  fun ref add_package(pkg: Package) =>
    let entry = _entries.get_or_else(pkg.name(), LockFileEntry)
    entry.packages.push(pkg)
    _entries(pkg.name()) = entry

  fun ref select(pkg: Package) ? =>
    let entry = _entries(pkg.name())?
    entry.selection = entry.packages.find(
      pkg where predicate = {(a, b) => a.string() == b.string() })?

  fun corrupt(): String iso^ =>
    "".join(
      [ "corrupt lockfile ("
        _file.path.path
        ") please delete this file and retry"
      ].values())

  fun string(): String iso^ =>
    "".join(_entries.values())

  fun ref dispose() =>
    _file.set_length(0)
    _file.print(string())

interface tag PonyupNotify
  be log(level: LogLevel, msg: String)
  be write(str: String)
