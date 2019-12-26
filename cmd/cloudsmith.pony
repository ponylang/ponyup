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
    pkg_str.replace("-" + pkg.version + "-", "%20")
    if pkg.version != "latest" then pkg_str.append("%20" + pkg.version) end
    "".join(
      [ "?query="; consume pkg_str
        "%20status:completed"
        "&page=1&page_size=1"
      ].values())
