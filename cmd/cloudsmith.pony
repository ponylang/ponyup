primitive Cloudsmith
  """
  Builds Cloudsmith API URLs and query strings for package lookups.
  """

  fun pkg_name(pkg: Package): String iso^ =>
    """
    Transforms a package identifier into the Cloudsmith naming convention.
    """
    "-".join([pkg.name(); pkg.version; _platform(pkg.platform())].values())

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
    _query(pkg.name(), pkg.platform(), 1, false, pkg.version)

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
    _query(application_name, platform, page_size, all_platforms, "latest")

  fun _query(
    name: String,
    platform: String,
    count: I64,
    all_platforms: Bool,
    version: String)
    : String
  =>
    let q = recover String .> append("?query=") end
    q.append(name)
    if not all_platforms then
      q .> append("%20") .> append(_platform(platform))
    end
    if version != "latest" then
      q .> append("%20version:") .> append(version)
    end
    q
      .> append("%20status:completed&page=1&page_size=")
      .> append(count.string())
    consume q

  fun _platform(platform: String): String iso^ =>
    let p = platform.clone()
    p.replace("x86_64", "x86-64")
    if not p.contains("unknown-linux") then
      p.replace("linux", "unknown-linux")
    end
    if not p.contains("apple-darwin") then
      p.replace("darwin", "apple-darwin")
    end
    if not p.contains("pc-windows") then p.replace("windows", "pc-windows") end
    consume p
