primitive _NightlyIndex
  fun parse(
    html: String,
    tool: String,
    previous: Array[String] val)
    : (Array[String] val, Bool) ?
  =>
    let start = html.find("<div id=\"package-results\">")?
    let prefix: String val =
      "href=\"/orgs/ponylang/packages/container/package/nightly%2F"
    let names = recover iso Array[String] .> append(previous) end
    var cursor = start
    var matched = false
    while true do
      let link = try html.find(prefix, cursor)? else break end
      let from = link + prefix.size().isize()
      cursor = html.find("\"", from)?
      let name: String val = html.substring(from, cursor)
      if name.at(tool + "-") then
        if not _GitHubName.segment(name) then error end
        matched = true
        if not names.contains(name, {(a, b) => a == b }) then
          names.push(name)
        end
      end
    end
    let more = html.contains("rel=\"next\"", start)
    if not matched then
      if more or (not html.contains("No results matched your search.", start))
      then
        error
      end
    end
    (consume names, more)

  fun merge(
    left: Array[HostedPackage] val,
    right: Array[HostedPackage] val,
    count: USize)
    : Array[HostedPackage] val
  =>
    let rows = recover iso Array[HostedPackage] end
    var i: USize = 0
    var j: USize = 0
    while rows.size() < count do
      try
        let take_left =
          if i >= left.size() then false
          elseif j >= right.size() then true
          else
            let a = left(i)?
            let b = right(j)?
            (a.version > b.version) or
              ((a.version == b.version) and (a.filename < b.filename))
          end
        if take_left then
          rows.push(left(i)?)
          i = i + 1
        else
          rows.push(right(j)?)
          j = j + 1
        end
      else
        break
      end
    end
    consume rows
