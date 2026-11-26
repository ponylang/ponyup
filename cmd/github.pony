use "crypto"
use "collections"
use http_client = "http_client"
use "json"

class val HostedPackage
  """
  A package archive listed by a hosting service.
  """
  let version: String
  let filename: String

  new val create(version': String, filename': String) =>
    version = version'
    filename = filename'

class val HostedDownload
  """
  An archive URL and the digest used to verify its contents.
  """
  let version: String
  let url: String
  let checksum: String
  let algorithm: (SHA256 | SHA512)
  let bearer: String

  new val create(
    version': String,
    url': String,
    checksum': String,
    algorithm': (SHA256 | SHA512),
    bearer': String)
    ?
  =>
    let length: USize = if algorithm' is SHA256 then 64 else 128 end
    if checksum'.size() != length then error end
    for c in checksum'.values() do
      if not (((c >= '0') and (c <= '9')) or ((c >= 'a') and (c <= 'f'))) then
        error
      end
    end
    version = version'
    url = url'
    checksum = checksum'
    algorithm = algorithm'
    bearer = bearer'

type _ListCallback is {((Array[HostedPackage] val | QueryError))} val
type _DownloadCallback is {((HostedDownload | None | QueryError))} val

class val GitHub
  """
  Finds tool archives in GitHub Releases and the GitHub Container Registry.
  """
  let _http: HostedHTTP
  let _token: String

  new val create(http: HostedHTTP, github_token: String) =>
    _http = http
    _token = github_token

  fun val list(
    pkg: Package,
    count: USize,
    all_platforms: Bool,
    cb: _ListCallback)
  =>
    """
    Lists up to count matching archives, newest version first.
    """
    if count == 0 then cb(recover val Array[HostedPackage] end); return end
    match pkg.channel
    | "release" =>
      _release_page(
        pkg.update_version("latest"), count, all_platforms, 1, [], cb)
    | "nightly" if all_platforms => _platform_page(pkg.name(), count, 1, [], cb)
    | "nightly" =>
      _registry_token(
        _GitHubName.repo(pkg),
        {(token)(self = this, pkg, cb) =>
          match \exhaustive\ token
          | let t: String => self._tags(
              _GitHubName.repo(pkg),
              _GitHubName.filename(pkg),
              t,
              count,
              "",
              [],
              cb)
          | None => cb(recover val Array[HostedPackage] end)
          | QueryError => cb(QueryError)
          end
        })
    else
      cb(QueryError)
    end

  fun val resolve(pkg: Package, cb: _DownloadCallback) =>
    """
    Returns the download URL and expected digest for a pinned or latest version.
    """
    match pkg.channel
    | "release" =>
      _release_page(
        pkg,
        1,
        false,
        if pkg.version == "latest" then 0 else 1 end,
        [],
        {(result)(self = this) =>
          match \exhaustive\ result
          | let rows: Array[HostedPackage] val =>
            try self._checksum(pkg, rows(0)?, cb) else cb(None) end
          | QueryError => cb(QueryError)
          end
        })
    | "nightly" =>
      _registry_token(
        _GitHubName.repo(pkg),
        {(token)(self = this, pkg, cb) =>
          match \exhaustive\ token
          | let t: String =>
            if pkg.version == "latest" then
              self._tags(
                _GitHubName.repo(pkg),
                _GitHubName.filename(pkg),
                t,
                1,
                "",
                [],
                {(result) =>
                  match \exhaustive\ result
                  | let rows: Array[HostedPackage] val =>
                    try self._manifest(pkg, t, rows(0)?.version, cb)
                    else cb(None)
                    end
                  | QueryError => cb(QueryError)
                  end
                })
            elseif _GitHubName.date(pkg.version) then
              self._manifest(pkg, t, pkg.version, cb)
            else
              cb(None)
            end
          | None => cb(None)
          | QueryError => cb(QueryError)
          end
        })
    else
      cb(QueryError)
    end

  fun val _release_page(
    pkg: Package,
    count: USize,
    all_platforms: Bool,
    page: USize,
    previous: Array[HostedPackage] val,
    cb: _ListCallback)
  =>
    let base: String val =
      "https://api.github.com/repos/ponylang/" + pkg.name() + "/releases"
    let url: String val =
      if page == 0 then
        base + "/latest"
      elseif pkg.version == "latest" then
        base + "?per_page=20&page=" + page.string()
      elseif _GitHubName.segment(pkg.version) then
        base + "/tags/" + pkg.version
      else
        cb(recover val Array[HostedPackage] end)
        return
      end
    _http.get(
      url,
      _token,
      "application/vnd.github+json",
      {(result)(self = this) =>
        try
          let response = result as http_client.HTTPResponse
          if (response.status == 404) and (page == 0) then
            self._release_page(pkg, count, all_platforms, 1, [], cb)
            return
          elseif (response.status == 404) and (pkg.version != "latest") then
            cb(recover val Array[HostedPackage] end)
            return
          end
          if response.status != 200 then error end
          let json = JSONParser.parse(String.from_array(response.body))
          let rows: Array[HostedPackage] val =
            recover val
              let found = Array[HostedPackage] .> append(previous)
              if (page != 0) and (pkg.version == "latest") then
                for release in (json as JSONArray).values() do
                  self._release_rows(
                    pkg, release as JSONObject, all_platforms, count, found)?
                  if found.size() >= count then break end
                end
              else
                self._release_rows(
                  pkg, json as JSONObject, all_platforms, count, found)?
              end
              found
            end
          if (pkg.version == "latest") and (rows.size() < count) and
            ((page == 0) or _GitHubName.more(response))
          then
            self._release_page(
              pkg, count, all_platforms, page + 1, rows, cb)
          else
            cb(rows)
          end
        else
          cb(QueryError)
        end
      })

  fun val _release_rows(
    pkg: Package,
    release: JSONObject,
    all_platforms: Bool,
    count: USize,
    rows: Array[HostedPackage] ref)
    ?
  =>
    if (release("draft")? as Bool) or (release("prerelease")? as Bool) then
      return
    end
    let version = release("tag_name")? as String
    if not _GitHubName.segment(version) then return end
    let assets = release("assets")? as JSONArray
    let names = Set[String]
    for asset in assets.values() do
      let item = asset as JSONObject
      if (item("state")? as String) == "uploaded" then
        names.set(item("name")? as String)
      end
    end
    let target = _GitHubName.filename(pkg)
    for asset in assets.values() do
      let name = (asset as JSONObject)("name")? as String
      let matches =
        if all_platforms then
          name.at(pkg.name() + "-") and
            (name.at(".zip", -4) or name.at(".tar.gz", -7))
        else
          name == target
        end
      if matches and names.contains(name) and names.contains(name + ".sha512")
      then
        rows.push(HostedPackage(version, name))
        if rows.size() >= count then return end
      end
    end

  fun val _checksum(pkg: Package, row: HostedPackage, cb: _DownloadCallback) =>
    let url: String val = "https://github.com/ponylang/" + pkg.name() +
      "/releases/download/" + row.version + "/" + row.filename
    _http.get(
      url + ".sha512",
      "",
      "application/octet-stream",
      {(result) =>
        try
          let response = result as http_client.HTTPResponse
          if response.status != 200 then error end
          let digest: String val =
            String.from_array(response.body).clone() .> strip()
          cb(HostedDownload(row.version, url, digest, SHA512, "")?)
        else
          cb(QueryError)
        end
      })

  fun val _platform_page(
    tool: String,
    count: USize,
    page: USize,
    previous: Array[String] val,
    cb: _ListCallback)
  =>
    let url: String val = "https://github.com/orgs/ponylang/packages" +
      "?ecosystem=container&q=nightly%2F" + tool + "-&page=" + page.string()
    _http.get(
      url,
      "",
      "text/html",
      {(result)(self = this) =>
        try
          let response = result as http_client.HTTPResponse
          if response.status != 200 then error end
          let html = String.from_array(response.body)
          (let names, let more) = _NightlyIndex.parse(html, tool, previous)?
          if more then
            if names.size() == previous.size() then error end
            self._platform_page(tool, count, page + 1, names, cb)
          else
            self._platform_tags(names, 0, count, [], cb)
          end
        else
          cb(QueryError)
        end
      })

  fun val _platform_tags(
    names: Array[String] val,
    index: USize,
    count: USize,
    previous: Array[HostedPackage] val,
    cb: _ListCallback)
  =>
    let name = try names(index)? else cb(previous); return end
    let repo: String val = "ponylang/nightly/" + name
    let filename: String val =
      name + if name.at("-windows-msvc", -13) then ".zip" else ".tar.gz" end
    _registry_token(
      repo,
      {(token)(self = this, names, index, previous, count, cb) =>
        match \exhaustive\ token
        | let t: String =>
          self._tags(
            repo,
            filename,
            t,
            count,
            "",
            [],
            {(result) =>
              match \exhaustive\ result
              | let rows: Array[HostedPackage] val =>
                self._platform_tags(
                  names,
                  index + 1,
                  count,
                  _NightlyIndex.merge(previous, rows, count),
                  cb)
              | QueryError => cb(QueryError)
              end
            })
        | None | QueryError => cb(QueryError)
        end
      })

  fun val _registry_token(
    repo: String,
    cb: {((String | None | QueryError))} val)
  =>
    let url: String val =
      "https://ghcr.io/token?service=ghcr.io&scope=repository:" +
        repo + ":pull"
    _http.get(
      url,
      "",
      "application/json",
      {(result)(self = this) =>
        try
          let response = result as http_client.HTTPResponse
          if response.status == 403 then
            self._check_missing_repo(repo, cb)
            return
          end
          if response.status != 200 then error end
          let obj =
            JSONParser.parse(String.from_array(response.body)) as JSONObject
          cb(obj("token")? as String)
        else
          cb(QueryError)
        end
      })

  fun val _check_missing_repo(
    repo: String,
    cb: {((String | None | QueryError))} val)
  =>
    let name = repo.substring("ponylang/nightly/".size().isize())
    let url: String val =
      "https://github.com/orgs/ponylang/packages/container/package/nightly%2F" +
      consume name
    _http.get(
      url,
      "",
      "text/html",
      {(result) =>
        match result
        | let response: http_client.HTTPResponse if response.status == 404 =>
          cb(None)
        else
          cb(QueryError)
        end
      })

  fun val _tags(
    repo: String,
    filename: String,
    token: String,
    count: USize,
    last: String,
    previous: Array[String] val,
    cb: _ListCallback)
  =>
    var url: String val =
      "https://ghcr.io/v2/" + repo + "/tags/list?n=100"
    if last != "" then url = url + "&last=" + last end
    _http.get(
      url,
      token,
      "application/json",
      {(result)(self = this) =>
        try
          let response = result as http_client.HTTPResponse
          if response.status != 200 then error end
          let obj =
            JSONParser.parse(String.from_array(response.body)) as JSONObject
          let tags = obj("tags")? as JSONArray
          let dates = recover iso Array[String] .> append(previous) end
          var cursor = last
          for entry in tags.values() do
            cursor = entry as String
            if _GitHubName.date(cursor) then dates.push(cursor) end
          end
          if _GitHubName.more(response) then
            if (cursor <= last) or (not _GitHubName.segment(cursor)) then
              error
            end
            self._tags(repo, filename, token, count, cursor, consume dates, cb)
          else
            let sorted = Sort[Array[String], String](consume dates)
            sorted.reverse_in_place()
            let rows = recover iso Array[HostedPackage] end
            for version in sorted.values() do
              if rows.size() >= count then break end
              rows.push(HostedPackage(version, filename))
            end
            cb(consume rows)
          end
        else
          cb(QueryError)
        end
      })

  fun val _manifest(
    pkg: Package,
    token: String,
    version: String,
    cb: _DownloadCallback)
  =>
    let base: String val = "https://ghcr.io/v2/" + _GitHubName.repo(pkg)
    _http.get(
      base + "/manifests/" + version,
      token,
      "application/vnd.oci.image.manifest.v1+json",
      {(result) =>
        try
          let response = result as http_client.HTTPResponse
          if response.status == 404 then cb(None); return end
          if response.status != 200 then error end
          let obj =
            JSONParser.parse(String.from_array(response.body)) as JSONObject
          if (obj("artifactType")? as String) !=
            "application/vnd.ponylang.nightly.v1"
          then
            error
          end
          let layers = obj("layers")? as JSONArray
          if layers.size() != 1 then error end
          let layer = layers(0)? as JSONObject
          let annotations = layer("annotations")? as JSONObject
          if (annotations("org.opencontainers.image.title")? as String) !=
            _GitHubName.filename(pkg)
          then
            error
          end
          let digest = layer("digest")? as String
          let hash: String val = digest.substring(7)
          if not digest.at("sha256:") then error end
          cb(HostedDownload(
            version, base + "/blobs/" + digest, hash, SHA256, token)?)
        else
          cb(QueryError)
        end
      })

primitive _GitHubName
  fun triple(pkg: Package): String =>
    let cpu = if pkg.cpu is AMD64 then "x86-64" else "arm64" end
    match \exhaustive\ pkg.os
    | Linux =>
      match pkg.distro
      | let distro: String => cpu + "-unknown-linux-" + distro
      else cpu + "-unknown-linux"
      end
    | Windows => cpu + "-pc-windows-msvc"
    | Darwin => cpu + "-apple-darwin"
    end

  fun filename(pkg: Package): String =>
    pkg.name() + "-" + triple(pkg) +
      if pkg.os is Windows then ".zip" else ".tar.gz" end

  fun repo(pkg: Package): String =>
    "ponylang/nightly/" + pkg.name() + "-" + triple(pkg)

  fun more(response: http_client.HTTPResponse): Bool =>
    match response.headers.get("link")
    | let link: String => link.contains("rel=\"next\"")
    else false
    end

  fun segment(s: String): Bool =>
    if (s == "") or (s == ".") or (s == "..") then return false end
    for c in s.values() do
      if not (((c >= '0') and (c <= '9')) or ((c >= 'a') and (c <= 'z')) or
        ((c >= 'A') and (c <= 'Z')) or (c == '.') or (c == '-') or (c == '_'))
      then
        return false
      end
    end
    true

  fun date(s: String): Bool =>
    if s.size() != 8 then return false end
    for c in s.values() do
      if (c < '0') or (c > '9') then return false end
    end
    true
