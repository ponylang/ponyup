use "json"

interface val Package is Stringable
  fun name(): String
  fun repo(): String
  fun version(): (String | None)
  fun libc(): (String | None)
  fun source_url(): String
  fun query(): String
  fun parse_sync(res: String): SyncInfo ?
  fun string(): String iso^
  fun update_version(version': String): Package

primitive Packages
  fun apply(): Array[String] box =>
    ["changelog-tool"; "corral"; "ponyc"; "ponyup"; "stable"]

  fun from_string(str: String): Package ? =>
    let fragments = str.split("-")
    match (fragments(0)?, fragments(1)?)
    | ("changelog", "tool") =>
      fragments.delete(1)?
      fragments(0)? = "changelog-tool"
    end
    from_fragments(
      fragments(0)?,
      fragments(1)?,
      fragments(2)?,
      try fragments(3)? end)?

  fun from_fragments(
    name: String,
    repo: String,
    version: String,
    libc: (String | None) = None)
    : Package ?
  =>
  let version' = if version != "latest" then consume version end
  match repo
  | "nightly" => Cloudsmith(name, "nightlies", version', libc)
  | "release" => Cloudsmith(name, "releases", version', libc)
  else error
  end


class val Cloudsmith is Package
  let _name: String
  let _repo: String
  let _version: (String | None)
  let _libc: (String | None)

  new val create(
    name': String,
    repo': String,
    version': (String | None) = None,
    libc': (String | None) = None)
  =>
    _name = name'
    _repo = repo'
    _version = version'
    _libc = libc'

  fun name(): String =>
    _name

  fun repo(): String =>
    match _repo
    | "nightlies" => "nightly"
    | "releases" => "release"
    else _repo
    end

  fun version(): (String | None) =>
    _version

  fun libc(): (String | None) =>
    _libc

  fun source_url(): String =>
    "".join(
      [ "https://api.cloudsmith.io/packages/ponylang/"; _repo; "/"
      ].values())

  fun query(): String =>
    "".join(
      [ "?query="; _name
        if _name == "ponyc"
        then try "%20" + (_libc as String) else "" end
        else ""
        end
        match _version
        | let v: String => "%20" + v
        | None => ""
        end
        "%20status:completed"
        "&page=1&page_size=1"
      ].values())

  fun parse_sync(res: String): SyncInfo ? =>
    let json_doc = JsonDoc .> parse(res)?
    let obj = (json_doc.data as JsonArray).data(0)? as JsonObject
    SyncInfo(
      obj.data("version")? as String,
      obj.data("checksum_sha512")? as String,
      obj.data("cdn_url")? as String)

  fun string(): String iso^ =>
    let fragments =
      [ _name
        repo()
        match _version
        | let v: String => v
        | None => "latest"
        end
      ]
    if _name == "ponyc" then try fragments.push(_libc as String) end end
    "-".join(fragments.values())

  fun update_version(version': String): Cloudsmith =>
    create(_name, _repo, version', _libc)

class val SyncInfo
  let version: String
  let checksum: String
  let download_url: String

  new val create(version': String, checksum': String, download_url': String) =>
    version = version'
    checksum = checksum'
    download_url = download_url'
