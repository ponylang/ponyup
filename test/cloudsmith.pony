use cli = "cli"
use "pony_test"
use "../cmd"

class \nodoc\ iso _TestCloudsmithResolve is UnitTest
  let _case: String

  new iso create(which: String) => _case = which

  fun name(): String => "cloudsmith/resolve/" + _case

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let which = _case
    let pkg = _HostedFixtures.package("nightlies", "20261125")?
    let url: String val = "https://api.cloudsmith.io/packages/ponylang/" +
      "nightlies/?query=corral%20x86-64-unknown-linux%20version:20261125" +
      "%20status:completed&page=1&page_size=1"
    let archive_url = "https://dl.cloudsmith.io/archive.tar.gz"
    let checksum: String val = "f".mul(128)
    let row: String val = "[{\"version\":\"20261125\",\"cdn_url\":\"" +
      archive_url + "\",\"checksum_sha512\":\"" + checksum + "\"}]"
    let body: String val =
      match which
      | "empty" => "[]"
      | "malformed" => "[{\"version\":\"20261125\"}]"
      else row
      end
    let status: U16 = if which == "unavailable" then 503 else 200 end
    let http = _HostedFixture(h, [_HostedReply(url, "", body, status)])
    PackageSources("cloudsmith", http, "api").resolve(
      pkg,
      {(result) =>
        match which
        | "found" =>
          try
            let item = result as HostedDownload
            h.assert_eq[String]("20261125", item.version)
            h.assert_eq[String](archive_url, item.url)
            h.assert_eq[String](checksum, item.checksum)
            h.assert_eq[String]("", item.bearer)
          else
            h.fail("expected Cloudsmith download")
          end
        | "empty" => h.assert_true(result is None)
        else h.assert_true(result is QueryError)
        end
        h.complete(true)
      })

class \nodoc\ iso _TestCloudsmithList is UnitTest
  let _case: String

  new iso create(which: String) => _case = which

  fun name(): String => "cloudsmith/list/" + _case

  fun apply(h: TestHelper) ? =>
    h.long_test(5_000_000_000)
    let which = _case
    let pkg = _HostedFixtures.package("release", "latest")?
    let url: String val =
      "https://api.cloudsmith.io/packages/ponylang/" +
      "releases/?query=corral%20status:completed&page=1&page_size=2"
    let rows =
      "[{\"version\":\"1.2\",\"filename\":\"a.tar.gz\"}," +
      "{\"version\":\"1.1\",\"filename\":\"b.zip\"}," +
      "{\"version\":\"1.0\",\"filename\":\"c.zip\"}]"
    let body: String val =
      match which
      | "empty" => "[]"
      | "malformed" => "[{\"version\":\"1.2\"}]"
      else rows
      end
    let status: U16 = if which == "unavailable" then 503 else 200 end
    let http = _HostedFixture(h, [_HostedReply(url, "", body, status)])
    PackageSources("cloudsmith", http, "api").list(
      pkg,
      2,
      true,
      {(result) =>
        if (which == "found") or (which == "empty") then
          try
            let items = result as Array[HostedPackage] val
            if which == "empty" then
              h.assert_eq[USize](0, items.size())
            else
              h.assert_eq[USize](2, items.size())
              h.assert_eq[String]("1.2", items(0)?.version)
              h.assert_eq[String]("a.tar.gz", items(0)?.filename)
              h.assert_eq[String]("1.1", items(1)?.version)
              h.assert_eq[String]("b.zip", items(1)?.filename)
            end
          else
            h.fail("expected Cloudsmith list")
          end
        else
          h.assert_true(result is QueryError)
        end
        h.complete(true)
      })

class \nodoc\ iso _TestSourceOption is UnitTest
  let _cloudsmith: Bool

  new iso create(cloudsmith: Bool) => _cloudsmith = cloudsmith

  fun name(): String =>
    "source/option/" + if _cloudsmith then "cloudsmith" else "default" end

  fun apply(h: TestHelper) ? =>
    let args = Array[String] .> push("ponyup")
    if _cloudsmith then args.push("--source=cloudsmith") end
    args.append(["find"; "corral"; "release"])
    let command = CLI.parse(args, None, "") as cli.Command
    let option = command.option("source").string()
    let expected = if _cloudsmith then "cloudsmith" else "github" end
    h.assert_eq[String](expected, option)
    let source = PackageSources(option, _HostedFixture(h, []), "")
    match source
    | let _: GitHub => h.assert_false(_cloudsmith)
    else h.assert_true(_cloudsmith)
    end
    h.long_test(5_000_000_000)
    source.list(
      _HostedFixtures.package("release", "latest")?,
      0,
      true,
      {(result) =>
        try
          h.assert_eq[USize](0, (result as Array[HostedPackage] val).size())
        else
          h.fail("expected no results for zero-count listing")
        end
        h.complete(true)
      })
