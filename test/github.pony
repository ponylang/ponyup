use "crypto"
use http_client = "http_client"
use "pony_test"
use "../cmd"

class \nodoc\ val _HostedReply
  let url: String
  let bearer: String
  let accept: (String | None)
  let response: http_client.HTTPResponse

  new val create(
    url': String,
    bearer': String,
    body: String,
    status: U16 = 200,
    more: Bool = false,
    accept': (String | None) = None)
  =>
    url = url'
    bearer = bearer'
    accept = accept'
    let headers: http_client.Headers val =
      recover val
        let out = http_client.Headers
        if more then out.set("Link", "<next>; rel=\"next\"") end
        out
      end
    response =
      http_client.HTTPResponse(
        http_client.HTTP11, status, "", headers, body.array())

class \nodoc\ val _HostedFixture is HostedHTTP
  let _h: TestHelper
  let _replies: Array[_HostedReply] val

  new val create(h: TestHelper, replies: Array[_HostedReply] val) =>
    _h = h
    _replies = replies

  fun get(
    url: String,
    bearer: String,
    accept: String,
    cb: {(HTTPResult)} val)
  =>
    for reply in _replies.values() do
      if reply.url == url then
        _h.assert_eq[String](reply.bearer, bearer)
        match reply.accept
        | let expected: String => _h.assert_eq[String](expected, accept)
        end
        cb(reply.response)
        return
      end
    end
    _h.fail("unexpected metadata request: " + url)
    cb(QueryError)

primitive \nodoc\ _HostedFixtures
  fun release_api(): String =>
    "https://api.github.com/repos/ponylang/corral/releases"

  fun releases(
    version: String,
    arch: String,
    archive_state: String = "uploaded",
    checksum: String = "uploaded")
    : String
  =>
    let filename: String val = "corral-" + arch + "-unknown-linux.tar.gz"
    "{\"draft\":false,\"prerelease\":false,\"tag_name\":\"" + version +
      "\",\"assets\":[{\"state\":\"" + archive_state + "\",\"name\":\"" +
      filename + "\"},{\"state\":\"" + checksum + "\",\"name\":\"" +
      filename + ".sha512\"}]}"

  fun archive(): String =>
    "https://github.com/ponylang/corral/releases/download/1.2/" +
      "corral-x86-64-unknown-linux.tar.gz"

  fun sha512(): String => "a".mul(128)

  fun registry(): String =>
    "https://ghcr.io/v2/ponylang/nightly/corral-x86-64-unknown-linux"

  fun token(): _HostedReply =>
    _HostedReply(
      "https://ghcr.io/token?service=ghcr.io&scope=repository:" +
        "ponylang/nightly/corral-x86-64-unknown-linux:pull",
      "",
      "{\"token\":\"pull\"}")

  fun pages(): Array[_HostedReply] val =>
    [ _HostedReply(release_api() + "/latest", "api", releases("1.3", "arm64"))
      _HostedReply(
        release_api() + "?per_page=20&page=1",
        "api",
        "[" + releases("1.5", "x86-64", "starter") + "," +
          releases("1.4", "x86-64" where checksum = "starter") + "," +
          releases("1.3", "arm64") + "]",
        200,
        true)
      _HostedReply(
        release_api() + "?per_page=20&page=2",
        "api",
        "[" + releases("1.2", "x86-64") + "," + releases("1.1", "x86-64") +
          "," + releases("1.0", "x86-64") + "]")
      _HostedReply(archive() + ".sha512", "", sha512() + "\n") ]

  fun manifest(
    hash: String,
    artifact: String = "application/vnd.ponylang.nightly.v1",
    filename: String = "corral-x86-64-unknown-linux.tar.gz",
    extra_layer: Bool = false)
    : String
  =>
    let layer: String val = "{\"digest\":\"sha256:" + hash +
      "\",\"annotations\":{\"org.opencontainers.image.title\":\"" + filename +
      "\"}}"
    let layers = if extra_layer then layer + "," + layer else layer end
    "{\"artifactType\":\"" + artifact + "\",\"layers\":[" + layers + "]}"

  fun package(channel: String, version: String): Package ? =>
    Packages.from_fragments(
      CorralApplication, channel, version, ["x86_64"; "linux"; "ubuntu26.04"])?

class \nodoc\ iso _TestHostedReleaseList is UnitTest
  fun name(): String => "github/release-list"

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let fixtures = _HostedFixtures
    let source =
      PackageSources("github", _HostedFixture(h, fixtures.pages()), "api")
    source.list(
      fixtures.package("release", "latest")?,
      2,
      false,
      {(result) =>
        try
          let rows = result as Array[HostedPackage] val
          h.assert_eq[USize](2, rows.size())
          h.assert_eq[String]("1.2", rows(0)?.version)
          h.assert_eq[String]("1.1", rows(1)?.version)
          h.assert_eq[String](
            "corral-x86-64-unknown-linux.tar.gz", rows(0)?.filename)
        else
          h.fail("expected two release archives")
        end
        h.complete(true)
      })

class \nodoc\ iso _TestHostedReleaseResolve is UnitTest
  let _version: String

  new iso create(version: String) => _version = version

  fun name(): String => "github/release-resolve/" + _version

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let fixtures = _HostedFixtures
    let replies: Array[_HostedReply] val =
      if _version == "latest" then
        fixtures.pages()
      else
        [ _HostedReply(
            fixtures.release_api() + "/tags/1.2",
            "api",
            fixtures.releases("1.2", "x86-64"))
          _HostedReply(
            fixtures.archive() + ".sha512", "", fixtures.sha512() + "\n") ]
      end
    GitHub(_HostedFixture(h, replies), "api").resolve(
      fixtures.package("release", _version)?,
      {(result) =>
        try
          let archive = result as HostedDownload
          h.assert_eq[String]("1.2", archive.version)
          h.assert_eq[String](fixtures.archive(), archive.url)
          h.assert_eq[String](fixtures.sha512(), archive.checksum)
          h.assert_true(archive.algorithm is SHA512)
          h.assert_eq[String]("", archive.bearer)
        else
          h.fail("expected the matching release archive")
        end
        h.complete(true)
      })

class \nodoc\ iso _TestHostedNightly is UnitTest
  let _version: String

  new iso create(version: String) => _version = version

  fun name(): String => "github/nightly/" + _version

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let fixtures = _HostedFixtures
    let repo = fixtures.registry()
    let digest: String val = "b".mul(64)
    let replies: Array[_HostedReply] val =
      recover val
        let entries = Array[_HostedReply] .> push(fixtures.token())
        if _version == "latest" then
          entries.push(_HostedReply(
            repo + "/tags/list?n=100",
            "pull",
            "{\"tags\":[\"20260530\"]}",
            200,
            true))
          entries.push(_HostedReply(
            repo + "/tags/list?n=100&last=20260530",
            "pull",
            "{\"tags\":[\"20260531\",\"latest\"]}"))
        end
        entries.push(_HostedReply(
          repo + "/manifests/20260531",
          "pull",
          fixtures.manifest(digest)
          where accept' = "application/vnd.oci.image.manifest.v1+json"))
        entries
      end
    GitHub(_HostedFixture(h, replies), "api").resolve(
      fixtures.package("nightly", _version)?,
      {(result) =>
        try
          let archive = result as HostedDownload
          h.assert_eq[String]("20260531", archive.version)
          h.assert_eq[String](repo + "/blobs/sha256:" + digest, archive.url)
          h.assert_eq[String](digest, archive.checksum)
          h.assert_true(archive.algorithm is SHA256)
          h.assert_eq[String]("pull", archive.bearer)
        else
          h.fail("expected a verified nightly archive")
        end
        h.complete(true)
      })

class \nodoc\ iso _TestHostedMetadataFailure is UnitTest
  let _case: String

  new iso create(case': String) => _case = case'

  fun name(): String => "github/failure/" + _case

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let fixtures = _HostedFixtures
    let which = _case
    let nightly = which.contains("manifest")
    let replies: Array[_HostedReply] val =
      if nightly then
        let hash: String val = "a".mul(64)
        let manifest =
          match which
          | "manifest-artifact" => fixtures.manifest(hash where artifact = "x")
          | "manifest-title" => fixtures.manifest(hash where filename = "other")
          | "manifest-layers" =>
            fixtures.manifest(hash where extra_layer = true)
          else fixtures.manifest("too-short")
          end
        [ fixtures.token()
          _HostedReply(
            fixtures.registry() + "/manifests/20260531",
            "pull",
            manifest) ]
      elseif which == "malformed-sha512" then
        [ _HostedReply(
            fixtures.release_api() + "/tags/1.2",
            "api",
            fixtures.releases("1.2", "x86-64"))
          _HostedReply(fixtures.archive() + ".sha512", "", "g".mul(128)) ]
      else
        let status: U16 = if which == "missing" then 404 else 403 end
        [ _HostedReply(
          fixtures.release_api() + "/tags/1.2", "api", "{}", status) ]
      end
    let pkg =
      if nightly then fixtures.package("nightly", "20260531")?
      else fixtures.package("release", "1.2")?
      end
    GitHub(_HostedFixture(h, replies), "api").resolve(
      pkg,
      {(result) =>
        if which == "missing" then
          h.assert_true(result is None)
        else
          h.assert_true(result is QueryError)
        end
        h.complete(true)
      })

primitive \nodoc\ _NightlyIndexFixture
  fun page(number: String): String =>
    "https://github.com/orgs/ponylang/packages?ecosystem=container" +
      "&q=nightly%2Fcorral-&page=" + number

  fun results(content: String): String =>
    "<div id=\"package-results\">" + content + "</div>"

  fun link(name: String): String =>
    "<a href=\"/orgs/ponylang/packages/container/package/nightly%2F" +
      name + "\">nightly/" + name + "</a>"

  fun more(): String =>
    "<a class=\"next_page\" aria-label=\"Next page\" rel=\"next\" " +
      "href=\"/orgs/ponylang/packages?ecosystem=container&amp;page=2" +
      "&amp;q=nightly%2Fcorral-\">Next</a>"

  fun token(name: String): _HostedReply =>
    _HostedReply(
      "https://ghcr.io/token?service=ghcr.io&scope=repository:" +
        "ponylang/nightly/" + name + ":pull",
      "",
      "{\"token\":\"" + name + "-pull\"}")

  fun tags(name: String): String =>
    "https://ghcr.io/v2/ponylang/nightly/" + name + "/tags/list?n=100"

class \nodoc\ iso _TestHostedNightlyAll is UnitTest
  fun name(): String => "github/nightly-all/list"

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let index = _NightlyIndexFixture
    let linux = "corral-x86-64-unknown-linux"
    let win = "corral-arm64-pc-windows-msvc"
    let replies: Array[_HostedReply] val =
      [ _HostedReply(
          index.page("1"),
          "",
          index.results(
            index.link(linux) + index.link("ponyc-arm64-apple-darwin") +
              index.more()))
        _HostedReply(
          index.page("2"),
          "",
          index.results(index.link(linux) + index.link(win)))
        index.token(linux)
        _HostedReply(
          index.tags(linux),
          linux + "-pull",
          "{\"tags\":[\"20260528\",\"20260530\",\"latest\"]}")
        index.token(win)
        _HostedReply(
          index.tags(win),
          win + "-pull",
          "{\"tags\":[\"20260529\",\"20260530\"]}",
          200,
          true)
        _HostedReply(
          index.tags(win) + "&last=20260530",
          win + "-pull",
          "{\"tags\":[\"20260531\"]}") ]
    GitHub(_HostedFixture(h, replies), "api").list(
      _HostedFixtures.package("nightly", "latest")?,
      4,
      true,
      {(result) =>
        try
          let rows = result as Array[HostedPackage] val
          let versions = Array[String]
          let filenames = Array[String]
          for row in rows.values() do
            versions.push(row.version)
            filenames.push(row.filename)
          end
          h.assert_array_eq[String](
            ["20260531"; "20260530"; "20260530"; "20260529"], versions)
          h.assert_array_eq[String](
            [win + ".zip"; win + ".zip"; linux + ".tar.gz"; win + ".zip"],
            filenames)
        else
          h.fail("expected nightly archives from both platforms")
        end
        h.complete(true)
      })

class \nodoc\ iso _TestHostedNightlyAllIndex is UnitTest
  let _case: String

  new iso create(case': String) => _case = case'

  fun name(): String => "github/nightly-all/" + _case

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let index = _NightlyIndexFixture
    let linux = "corral-x86-64-unknown-linux"
    let which = _case
    let replies: Array[_HostedReply] val =
      match which
      | "empty" =>
        [ _HostedReply(
            index.page("1"),
            "",
            index.results("<h3>No results matched your search.</h3>")) ]
      | "invalid-html" =>
        [ _HostedReply(index.page("1"), "", "<html>Sign in</html>") ]
      | "stalled-index" =>
        let html = index.results(index.link(linux) + index.more())
        [ _HostedReply(index.page("1"), "", html)
          _HostedReply(index.page("2"), "", html) ]
      | "unsafe-name" =>
        [ _HostedReply(
            index.page("1"), "", index.results(index.link("corral-../name"))) ]
      | "index-error" =>
        [ _HostedReply(
            index.page("1"),
            "",
            index.results(index.link(linux) + index.more()))
          _HostedReply(index.page("2"), "", "", 503) ]
      else
        [ _HostedReply(index.page("1"), "", index.results(index.link(linux)))
          index.token(linux)
          _HostedReply(
            index.tags(linux),
            linux + "-pull",
            "{\"tags\":[\"20260531\"]}",
            200,
            true)
          _HostedReply(
            index.tags(linux) + "&last=20260531",
            linux + "-pull",
            "",
            503) ]
      end
    GitHub(_HostedFixture(h, replies), "api").list(
      _HostedFixtures.package("nightly", "latest")?,
      1,
      true,
      {(result) =>
        if which == "empty" then
          try
            let rows = result as Array[HostedPackage] val
            h.assert_eq[USize](0, rows.size())
          else
            h.fail("expected an empty list of archives")
          end
        else
          h.assert_true(result is QueryError)
        end
        h.complete(true)
      })

class \nodoc\ iso _TestFindHostedNightlyAll is UnitTest
  fun name(): String => "github/nightly-all/find"

  fun apply(h: TestHelper) =>
    h.long_test(5_000_000_000)
    let index = _NightlyIndexFixture
    let name' = "corral-arm64-apple-darwin"
    let replies: Array[_HostedReply] val =
      [ _HostedReply(index.page("1"), "", index.results(index.link(name')))
        index.token(name')
        _HostedReply(
          index.tags(name'),
          name' + "-pull",
          "{\"tags\":[\"20260531\"]}") ]
    FindPackages(
      _FindNightlyOutput(h),
      GitHub(_HostedFixture(h, replies), "api"),
      "corral",
      ["nightly"],
      "",
      1,
      true)

actor \nodoc\ _FindNightlyOutput is PonyupNotify
  let _h: TestHelper

  new create(h: TestHelper) => _h = h

  be log(level: LogLevel, msg: String) =>
    match level
    | Err | InternalErr =>
      _h.fail(msg)
      _h.complete(false)
    end

  be write(str: String, ansi_color_code: String = "") =>
    if str.at("Tool ") then return end
    let fields = Array[String]
    for field in str.split().values() do
      if field != "" then fields.push(field) end
    end
    _h.assert_array_eq[String](
      ["corral"; "nightly"; "20260531"; "corral-arm64-apple-darwin.tar.gz"],
      fields)
    _h.complete(true)

  be complete(pkg: Package) => None

class \nodoc\ iso _TestNightlyAccessDenied is UnitTest
  let _operation: String
  let _status: U16

  new iso create(operation: String, status: U16) =>
    _operation = operation
    _status = status

  fun name(): String =>
    "github/nightly-access-denied/" + _operation + "/" + _status.string()

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let operation = _operation
    let status = _status
    let absent = status == 404
    let pkg = _HostedFixtures.package("nightly", "20260531")?
    let replies: Array[_HostedReply] val =
      recover val
        let entries = Array[_HostedReply]
        if operation == "all" then
          let index = _NightlyIndexFixture
          entries.push(_HostedReply(
            index.page("1"),
            "",
            index.results(index.link("corral-x86-64-unknown-linux"))))
        end
        entries
          .> push(_HostedReply(_HostedFixtures.token().url, "", "", 403))
          .> push(_HostedReply(
            "https://github.com/orgs/ponylang/packages/container/package/" +
              "nightly%2Fcorral-x86-64-unknown-linux",
            "",
            "",
            status))
      end
    let github = GitHub(_HostedFixture(h, replies), "api")
    if operation == "resolve" then
      github.resolve(
        pkg,
        {(result) =>
          if absent then h.assert_true(result is None)
          else h.assert_true(result is QueryError)
          end
          h.complete(true)
        })
    else
      github.list(
        pkg,
        1,
        operation == "all",
        {(result) =>
          if absent and (operation == "list") then
            try
              let rows = result as Array[HostedPackage] val
              h.assert_eq[USize](0, rows.size())
            else
              h.fail("expected an empty list for an unpublished platform")
            end
          else
            h.assert_true(result is QueryError)
          end
          h.complete(true)
        })
    end
