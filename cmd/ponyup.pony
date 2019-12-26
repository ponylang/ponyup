use "collections"
use "files"
use "http"
use "json"
use "net"
use "process"
use "term"
use "time"

/*
 Main      Ponyup           HTTPSession       ProcessMonitor
  | sync     |                   |                  |
  | -------> | (HTTPGet)         |                  |
  |          | ----------------> |                  |
  |          |    query_response |                  |
  |          | <---------------- |                  |
  |          | (HTTPGet)         |                  |
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
  let _http_get: HTTPGet

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
    _http_get = HTTPGet(NetAuth(_auth), _notify)

  be sync(pkg: Package) =>
    try
      _lockfile.parse()?
    else
      _notify.log(Err, _lockfile.corrupt())
      return
    end

    if not Packages().contains(pkg.name, {(a, b) => a == b }) then
      _notify.log(Err, "unknown package: " + pkg.name)
      return
    end

    if _lockfile.contains(pkg) then
      _notify.log(Info, pkg.string() + " is up to date")
      return
    end

    _notify.log(Info, "updating " + pkg.string())
    let src_url = Cloudsmith.repo_url(pkg.channel)
    _notify.log(Info, "syncing updates from " + src_url)
    let query_string = src_url + Cloudsmith.query(pkg)
    _notify.log(Extra, "query url: " + query_string)

    _http_get(
      query_string,
      {(_)(self = recover tag this end, pkg) =>
        QueryHandler(_notify, {(res) => self.query_response(pkg, consume res) })
      })

  be query_response(pkg: Package, res: Array[JsonObject val] iso) =>
    (let version, let checksum, let download_url) =
      try
        res(0)?
        ( res(0)?.data("version")? as String
        , res(0)?.data("checksum_sha512")? as String
        , res(0)?.data("cdn_url")? as String )
      else
        _notify.log(Err, "".join(
          [ "requested package, "; pkg; ", was not found"
          ].values()))
        return
      end

    let pkg' = (consume pkg).update_version(version)

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
    _notify.log(Info, "pulling " + version)
    _notify.log(Extra, "download url: " + download_url)
    _notify.log(Extra, "install path: " + install_path.path)

    if (not _root.exists()) and (not _root.mkdir()) then
      _notify.log(Err, "unable to create directory: " + _root.path)
      return
    end

    let dump = DLDump(
      _notify,
      dl_path,
      {(checksum')(self = recover tag this end) =>
        self.dl_complete(pkg', install_path, dl_path, checksum, checksum')
      })

    _http_get(download_url, {(_)(dump) => DLHandler(dump) })

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
    if _lockfile.selection(pkg.name) is None then
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
      [ "selecting"; pkg; "as default for"; pkg.name
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

    let link_rel: String = "/".join(["bin"; pkg.name].values())
    let bin_rel: String = "/".join([pkg.string(); link_rel].values())
    try
      let bin_path = _root.join(bin_rel)?
      _notify.log(Info, " bin: " + bin_path.path)

      let link_dir = _root.join("bin")?
      if not link_dir.exists() then link_dir.mkdir() end

      let link_path = link_dir.join(pkg.name)?
      _notify.log(Info, "link: " + link_path.path)

      if link_path.exists() then link_path.remove() end
      if not bin_path.symlink(link_path) then error end
    else
      _notify.log(Err, "failed to create symbolic link")
      return
    end
    _lockfile.dispose()

  be show(package_name: String, local: Bool) =>
    try
      _lockfile.parse()?
    else
      _notify.log(Err, _lockfile.corrupt())
      return
    end

    let starts_with =
      {(p: String, s: String): Bool => s.substring(0, p.size().isize()) == p }

    let local_packages = recover Array[String] end
    for pkg in _lockfile.string().split("\n").values() do
      if (pkg != "") and not starts_with(package_name, pkg) then continue end
      local_packages.push(pkg)
    end

    let timeout: U64 = if not local then 5_000_000_000 else 0 end
    ShowPackages(_notify, _http_get, consume local_packages, timeout)

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

      let entry = _entries.get_or_else(pkg.name, LockFileEntry)
      if selected then
        entry.selection = entry.packages.size()
      end
      entry.packages.push(pkg)
      _entries(pkg.name) = entry
    end

  fun contains(pkg: Package): Bool =>
    if pkg.version == "latest" then return false end
    let entry = _entries.get_or_else(pkg.name, LockFileEntry)
    entry.packages.contains(pkg, {(a, b) => a.string() == b.string() })

  fun selection(pkg_name: String): (Package | None) =>
    try
      let entry = _entries(pkg_name)?
      entry.packages(entry.selection)?
    end

  fun ref add_package(pkg: Package) =>
    let entry = _entries.get_or_else(pkg.name, LockFileEntry)
    entry.packages.push(pkg)
    _entries(pkg.name) = entry

  fun ref select(pkg: Package) ? =>
    let entry = _entries(pkg.name)?
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

actor ShowPackages
  let _notify: PonyupNotify
  let _http_get: HTTPGet
  let _local: Array[String]
  embed _latest: Array[String] = []
  let _timers: Timers = Timers
  let _timer: Timer tag

  new create(
    notify: PonyupNotify,
    http_get: HTTPGet,
    local: Array[String] iso,
    timeout: U64)
  =>
    _notify = notify
    _http_get = http_get
    _local = consume local

    let timer = Timer(
      object iso is TimerNotify
        let self: ShowPackages = this

        fun apply(timer: Timer, count: U64): Bool =>
          if timeout != 0 then self.complete() end
          false

        fun cancel(timer: Timer) =>
          self.complete()
      end,
      timeout)
    _timer = recover tag timer end
    _timers(consume timer)

    if timeout == 0 then return end

    for repo in ["nightlies"; "releases"].values() do
      let query_string =
        Cloudsmith.repo_url(repo) + "?page=1&query=tag%3Alatest"
      _notify.log(Extra, "query url: " + query_string)
      _http_get(
        query_string,
        {(_)(self = recover tag this end, repo) =>
          QueryHandler(
            _notify,
            {(res) =>
              let packages = recover Array[String] end
              for obj in (consume res).values() do
                try
                  let filename = obj.data("filename")? as String
                  var glibc: (String | None) = None
                  if filename.contains("gnu") then glibc = "gnu" end
                  if filename.contains("musl") then glibc = "musl" end
                  packages.push(Packages.from_string("-".join(
                    [ filename.split("-")(0)?
                      repo
                      obj.data("version")? as String
                      glibc
                    ].values()))?.string())
                end
              end
              self.append(consume packages)
            })
        })
    end

  be append(packages: Array[String] iso) =>
    _latest.append(consume packages)
    // note that `_latest` may contain duplicates for packages containing
    // libc fragments
    if _latest.size() >= (Packages().size() * 2) then
      _timers.cancel(_timer)
    end

  be complete() =>
    Sort[Array[String], String](_local)
    _local.reverse_in_place()

    for package in _local.values() do
      _notify.write(
          package,
          if package.contains("*") then ANSI.bright_green() else "" end)

      if not package.contains("*") then
        _notify.write("\n")
        continue
      end

      let pkg = try package.split(" ")(0)? else package end
      let frags = pkg.split("-")
      let pred =
        {(a: String, b: String): Bool => try a.split(" ")(0)? else a end == b }
      for update in _latest.values() do
        if
          (_local.contains(update, pred))
            or (pkg.contains("gnu") and not update.contains("gnu"))
            or (pkg.contains("musl") and not update.contains("musl"))
        then
          continue
        end

        let frags' = update.split("-")
        try
          if (frags(0)? == frags'(0)?) and (frags(1)? == frags'(1)?) then
            _notify .> write(" -- ") .> write(update, ANSI.yellow())
          end
        end
      end
      _notify.write("\n")
    end

interface tag PonyupNotify
  be log(level: LogLevel, msg: String)
  be write(str: String, ansi_color_code: String = "")
