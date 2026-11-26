use "crypto"
use http_client = "http_client"
use "json"

type _QueryResult is (Array[JSONObject val] iso | QueryError)

interface val PackageSource
  """
  Resolves installable archives and lists versions for a package.
  """

  fun val resolve(
    pkg: Package,
    cb: {((HostedDownload | None | QueryError))} val)
    """
    Returns the requested archive, or None if it was not published.
    """

  fun val list(
    pkg: Package,
    count: USize,
    all_platforms: Bool,
    cb: {((Array[HostedPackage] val | QueryError))} val)
    """
    Lists matching archives, newest first, up to count.
    """

primitive PackageSources
  """
  Creates the hosting client selected for this invocation.
  """
  fun apply(source: String, http: HostedHTTP, github_token: String)
    : PackageSource
  =>
    """
    Uses GitHub unless the caller explicitly selects Cloudsmith.
    """
    if source == "cloudsmith" then _CloudsmithSource(http)
    else GitHub(http, github_token)
    end

class val _CloudsmithSource is PackageSource
  let _http: HostedHTTP

  new val create(http: HostedHTTP) => _http = http

  fun val resolve(
    pkg: Package,
    cb: {((HostedDownload | None | QueryError))} val)
  =>
    _query(
      Cloudsmith.repo_url(pkg.channel) + Cloudsmith.query(pkg),
      {(result) =>
        match \exhaustive\ consume result
        | let rows: Array[JSONObject val] iso =>
          if rows.size() == 0 then
            cb(None)
          else
            try
              let row = rows(0)?
              cb(HostedDownload(
                row("version")? as String,
                row("cdn_url")? as String,
                row("checksum_sha512")? as String,
                SHA512,
                "")?)
            else
              cb(QueryError)
            end
          end
        | QueryError => cb(QueryError)
        end
      })

  fun val list(
    pkg: Package,
    count: USize,
    all_platforms: Bool,
    cb: {((Array[HostedPackage] val | QueryError))} val)
  =>
    if count == 0 then cb(recover val Array[HostedPackage] end); return end
    let query =
      Cloudsmith.find_query(
        pkg.name(), pkg.platform(), count.i64(), all_platforms)
    let url: String = Cloudsmith.repo_url(pkg.channel) + query
    _query(
      url,
      {(result) =>
        match \exhaustive\ consume result
        | let rows: Array[JSONObject val] iso =>
          try
            let entries = recover iso Array[HostedPackage] end
            for row in (consume rows).values() do
              if entries.size() >= count then break end
              entries.push(HostedPackage(
                row("version")? as String, row("filename")? as String))
            end
            cb(consume entries)
          else
            cb(QueryError)
          end
        | QueryError => cb(QueryError)
        end
      })

  fun _query(url: String, cb: {(_QueryResult)} val) =>
    _http.get(
      url,
      "",
      "application/json",
      {(result) =>
        try
          let response = result as http_client.HTTPResponse val
          if response.status != 200 then error end
          let arr =
            JSONParser.parse(String.from_array(response.body)) as JSONArray
          let rows = recover iso Array[JSONObject val] end
          for row in arr.values() do rows.push(row as JSONObject) end
          cb(consume rows)
        else
          cb(QueryError)
        end
      })

primitive GitHubToken
  """
  Reads the optional GitHub API token for release discovery.
  """

  fun apply(env: Env): String =>
    """
    Returns an empty token for anonymous requests.
    """
    for value in env.vars.values() do
      if value.at("GITHUB_TOKEN=") then return value.substring(13) end
    end
    ""
