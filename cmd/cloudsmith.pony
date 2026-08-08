primitive Cloudsmith
  """
  Builds Cloudsmith API URLs and query strings for package lookups.
  """

  fun pkg_name(pkg: Package): String iso^ =>
    """
    Transforms a package identifier into the Cloudsmith naming convention.
    """
    pkg.string()
      .> replace("-nightly", "")
      .> replace("-release", "")
      .> replace("-x86_64-", "-x86-64-")
      .> replace("-linux", "-unknown-linux")
      .> replace("-darwin", "-apple-darwin")
      .> replace("-windows", "-pc-windows")

  fun repo_url(repo': String): String =>
    """
    Returns the Cloudsmith API base URL for the given repo channel.
    """
    let repo_name =
      match \exhaustive\ consume repo'
      | "nightly" => "nightlies"
      | "release" => "releases"
      | let s: String => s
      end
    "".join(
      [ "https://api.cloudsmith.io/packages/ponylang/"
        repo_name; "/"
      ].values())

  fun query(pkg: Package): String =>
    """
    Builds a Cloudsmith query string for a specific package version.
    """
    let pkg_str = pkg_name(pkg)
    pkg_str.replace("-" + pkg.version + "-", "%20")
    if pkg.version != "latest" then
      pkg_str.append("%20version:" + pkg.version)
    end
    "".join(
      [ "?query="; consume pkg_str
        "%20status:completed"
        "&page=1&page_size=1"
      ].values())

  fun find_query(
    application_name: String,
    platform: String,
    page_size: I64,
    all_platforms: Bool)
    : String
  =>
    """
    Builds a Cloudsmith query string for discovering available versions.
    """
    let q = recover String end
    q.append(application_name)
    if not all_platforms then
      // Transform platform to match Cloudsmith package naming convention
      // (e.g. x86_64-linux-ubuntu26.04 ->
      // x86-64-unknown-linux-ubuntu26.04). Guards prevent
      // double-transformation if already in Cloudsmith format.
      let p = platform.clone()
      if not p.contains("x86-64") then
        p.replace("x86_64", "x86-64")
      end
      if not p.contains("unknown-linux") then
        p.replace("linux", "unknown-linux")
      end
      if not p.contains("apple-darwin") then
        p.replace("darwin", "apple-darwin")
      end
      if not p.contains("pc-windows") then
        p.replace("windows", "pc-windows")
      end
      q .> append("%20") .> append(consume p)
    end
    q.append("%20status:completed")
    "".join(
      [ "?query="; consume q
        "&page=1&page_size="; page_size.string()
      ].values())
