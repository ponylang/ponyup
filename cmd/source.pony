use "json"

interface val Source
  fun name(): String
  fun url(): String
  fun query(package: String): String
  fun check_path(package: String): String
  fun parse_sync(res: String): SyncInfo ?
  fun string(): String

class val Nightly is Source
  let version: (String | None)

  new val create(version': (String | None) = None) =>
    version = version'

  fun name(): String =>
    "nightly"

  fun url(): String =>
    "https://api.cloudsmith.io/packages/main-pony/pony-nightlies/"

  fun query(package: String): String =>
    "".join(
      [ "?query="; package
        match version
        | let v: String => "%20" + v
        | None => "&page=1&page_size=1"
        end
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
    name() +
      match version
      | let v: String => "-" + v
      | None => ""
      end

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
