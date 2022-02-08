use "collections"
use "crypto"
use "files"
use "http"
use "json"
use "net"

class val HTTPGet
  let _auth: NetAuth
  let _notify: PonyupNotify

  new val create(auth: NetAuth, notify: PonyupNotify) =>
    _auth = auth
    _notify = notify

  fun apply(url_string: String, hf: HandlerFactory val) =>
    let client = HTTPClient(_auth where keepalive_timeout_secs = 10)
    let url =
      try
        URL.valid(url_string)?
      else
        _notify.log(InternalErr, "invalid url: " + url_string)
        return
      end

    let req = Payload.request("GET", url)
    req("User-Agent") = "ponyup"
    try
      client(consume req, hf)?
    else
      _notify.log(Err, "server unreachable, please try again later")
    end

class QueryHandler is HTTPHandler
  let _notify: PonyupNotify
  var _buf: String iso = recover String end
  let _cb: {(Array[JsonObject val] iso)} val

  new create(notify: PonyupNotify, cb: {(Array[JsonObject val] iso)} val) =>
    _notify = notify
    _cb = cb

  fun ref apply(res: Payload val) =>
    try
      let body' = recover String(res.body_size() as USize) end
      if (res.body_size() as USize) == 0 then return end
      for c in res.body()?.values() do chunk(c) end
      consume body'
      finished()
    end

  fun ref chunk(data: (String | Array[U8] val)) =>
    match data
    | let s: String => _buf.append(s)
    | let bs: Array[U8] val => _buf.append(String.from_array(bs))
    end

  fun ref finished() =>
    _notify.log(Extra, "received response of size " + _buf.size().string())
    let json_doc = recover trn JsonDoc end
    let result = recover Array[JsonObject val] end
    try
      json_doc.parse(_buf = recover String end)?
      for v in ((consume val json_doc).data as JsonArray val).data.values() do
        result.push(v as JsonObject val)
      end
    end
    _cb(consume result)

  fun failed(
    reason: (AuthFailed val | ConnectionClosed val | ConnectFailed val))
  =>
    _notify.log(Err, "server unreachable, please try again later")

class DLHandler is HTTPHandler
  let _dl_dump: DLDump
  new create(dl_dump: DLDump) => _dl_dump = dl_dump
  fun apply(res: Payload val) => _dl_dump(res)
  fun chunk(bs: ByteSeq val) => _dl_dump.chunk(bs)
  fun finished() => _dl_dump.finished()

actor DLDump
  let _notify: PonyupNotify
  let _file_path: FilePath
  let _cb: {(String)} val
  let _file_name: String
  let _file: File
  let _digest: Digest = Digest.sha512()
  var _total: USize = 0
  var _progress: USize = 0
  var _percent: USize = 0

  new create(notify: PonyupNotify, file_path: FilePath, cb: {(String)} val) =>
    _notify = consume notify
    _file_path = consume file_path
    _cb = consume cb

    let components = _file_path.path.split("/")
    _file_name = try components(components.size() - 1)? else "" end
    _file = File(_file_path)

  be apply(res: Payload val) =>
    _total =
      try res.headers()("Content-Length")?.usize()? else 0 end

  be chunk(bs: ByteSeq val) =>
    _progress = _progress + bs.size()
    let percent = ((_progress.f64() / _total.f64()) * 100).usize()
    if percent > _percent then
      let progress_bar = recover String end
      progress_bar.append("\r  |")
      for i in Range(0, 100, 2) do
        progress_bar.append(if i <= percent then
          ifdef windows then "#" else "█" end
        else
          "-"
        end)
      end
      progress_bar .> append("| ") .> append(_file_name)
      _notify.write(consume progress_bar)
      _percent = percent
    end

    _file.write(bs)
    try _digest.append(bs)? end

  be finished() =>
    _file.dispose()
    _notify.write("\n")
    _cb(ToHexString(_digest.final()))
