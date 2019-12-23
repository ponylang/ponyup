use "json"

primitive Cloudsmith
  fun pkg_name(pkg: Package): String iso^ =>
    let name = pkg.string()
    name.replace("-nightly", "")
    name.replace("-release", "")
    name.replace("-x86_64-", "-x86-64-")
    name.replace("-linux", "-unknown-linux")
    name.replace("-darwin", "-apple-darwin")
    name

  fun repo_url(repo': String): String =>
    let repo_name =
      match consume repo'
      | "nightly" => "nightlies"
      | "release" => "releases"
      | let s: String => s
      end
    "".join(
      [ "https://api.cloudsmith.io/packages/ponylang/"; repo_name; "/"
      ].values())

  fun query(pkg: Package): String =>
    let pkg_str = pkg_name(pkg)
    pkg_str.replace("-latest-", "%20")
    "".join(
      [ "?query="; consume pkg_str
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

class val SyncInfo
  let version: String
  let checksum: String
  let download_url: String

  new val create(version': String, checksum': String, download_url': String) =>
    version = version'
    checksum = checksum'
    download_url = download_url'
