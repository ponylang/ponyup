use "json"

interface val Source
  fun name(): String
  fun url(): String
  fun query(package: String): String
  fun check_path(package: String): String
  fun parse_sync(res: String): SyncInfo ?
  fun string(): String

primitive Sources
  fun nightly(libc: String, version: (String | None)): Source =>
    Cloudsmith("nightlies", libc, version)

  fun release(libc: String, version: (String | None)): Source =>
    Cloudsmith("releases", libc, version)

class val Cloudsmith is Source
  let repo: String
  let libc: String
  let version: (String | None)

  new val create(
    repo': String,
    libc': String = "gnu",
    version': (String | None) = None)
  =>
    repo = repo'
    libc = libc'
    version = version'

  fun name(): String =>
    match repo
    | "nightlies" => "nightly"
    | "releases" => "release"
    else repo
    end

  fun url(): String =>
    "".join(
      [ "https://api.cloudsmith.io/packages/ponylang/"; repo; "/"
      ].values())

  fun query(package: String): String =>
    "".join(
      [ "?query="; package
        if package == "ponyc" then "%20" + libc else "" end
        match version
        | let v: String => "%20" + v
        | None => ""
        end
        "%20status:completed"
        "&page=1&page_size=1"
      ].values())

  fun check_path(package: String): String =>
    match package
    | "ponyc" => "bin/ponyc"
    | "corral" => "bin/corral"
    | "stable" => "bin/stable"
    else ""
    end

  fun parse_sync(res: String): SyncInfo ? =>
    let json_doc = JsonDoc .> parse(res)?
    let obj = (json_doc.data as JsonArray).data(0)? as JsonObject
    SyncInfo(
      obj.data("filename")? as String,
      obj.data("version")? as String,
      obj.data("checksum_sha512")? as String,
      obj.data("cdn_url")? as String)

  fun string(): String =>
    "-".join(
      [ name()
        match version
        | let v: String => v
        | None => "latest"
        end
        libc
      ].values())

class val SyncInfo
  let filename: String
  let version: String
  let checksum: String
  let download_url: String

  new val create(
    filename': String,
    version': String,
    checksum': String,
    download_url': String)
  =>
    filename = filename'
    version = version'
    checksum = checksum'
    download_url = download_url'
