use "collections"
use courier = "courier"
use "files"
use "json"
use ssl_crypto = "ssl/crypto"
use lori = "lori"
use ssl_net = "ssl/net"

class val HTTPGet
  let _auth: lori.TCPConnectAuth
  let _ssl_ctx: ssl_net.SSLContext val
  let _notify: PonyupNotify

  new val create(auth: AmbientAuth, notify: PonyupNotify) =>
    _auth = lori.TCPConnectAuth(auth)
    _ssl_ctx = recover val ssl_net.SSLContext.>set_client_verify(false) end
    _notify = notify

  fun query(
    url_string: String,
    cb: {(Array[JsonObject val] iso)} val)
  =>
    match courier.URL.parse(url_string)
    | let url: courier.ParsedURL =>
      _QueryConnection(_auth, _ssl_ctx, url, _notify, cb)
    | let err: courier.URLParseError =>
      _notify.log(InternalErr, "invalid url: " + url_string)
    end

  fun download(url_string: String, dump: DLDump) =>
    match courier.URL.parse(url_string)
    | let url: courier.ParsedURL =>
      _DownloadConnection(_auth, _ssl_ctx, url, _notify, dump)
    | let err: courier.URLParseError =>
      _notify.log(InternalErr, "invalid url: " + url_string)
    end

actor _QueryConnection is courier.HTTPClientConnectionActor
  var _http: courier.HTTPClientConnection =
    courier.HTTPClientConnection.none()
  let _notify: PonyupNotify
  let _cb: {(Array[JsonObject val] iso)} val
  let _url: courier.ParsedURL val
  var _collector: courier.ResponseCollector = courier.ResponseCollector

  new create(
    auth: lori.TCPConnectAuth,
    ssl_ctx: ssl_net.SSLContext val,
    url: courier.ParsedURL val,
    notify: PonyupNotify,
    cb: {(Array[JsonObject val] iso)} val)
  =>
    _notify = notify
    _cb = cb
    _url = url
    _http =
      courier.HTTPClientConnection.ssl(
        auth, ssl_ctx, url.host, url.port, this,
        courier.ClientConnectionConfig)

  fun ref _http_client_connection(): courier.HTTPClientConnection => _http

  fun ref on_connected() =>
    let req = courier.Request.get(_url.request_path())
      .header("User-Agent", "ponyup")
      .build()
    _http.send_request(req)

  fun ref on_connection_failure(reason: courier.ConnectionFailureReason) =>
    _notify.log(Err, "server unreachable, please try again later")

  fun ref on_parse_error(err: courier.ParseError) =>
    _notify.log(Err, "server unreachable, please try again later")

  fun ref on_response(response: courier.Response val) =>
    _collector = courier.ResponseCollector
    _collector.set_response(response)

  fun ref on_body_chunk(data: Array[U8] val) =>
    _collector.add_chunk(data)

  fun ref on_response_complete() =>
    try
      let response = _collector.build()?
      let body_str = String.from_array(response.body)
      _notify.log(Extra,
        "received response of size " + body_str.size().string())
      let result = recover Array[JsonObject val] end
      match JsonParser.parse(body_str)
      | let arr: JsonArray =>
        for v in arr.values() do
          try result.push(v as JsonObject) end
        end
      end
      _cb(consume result)
    end
    _http.close()

actor _DownloadConnection is courier.HTTPClientConnectionActor
  var _http: courier.HTTPClientConnection =
    courier.HTTPClientConnection.none()
  let _notify: PonyupNotify
  let _dump: DLDump
  let _url: courier.ParsedURL val

  new create(
    auth: lori.TCPConnectAuth,
    ssl_ctx: ssl_net.SSLContext val,
    url: courier.ParsedURL val,
    notify: PonyupNotify,
    dump: DLDump)
  =>
    _notify = notify
    _dump = dump
    _url = url
    _http =
      courier.HTTPClientConnection.ssl(
        auth, ssl_ctx, url.host, url.port, this,
        courier.ClientConnectionConfig(where
          max_body_size' = 524_288_000))

  fun ref _http_client_connection(): courier.HTTPClientConnection => _http

  fun ref on_connected() =>
    let req = courier.Request.get(_url.request_path())
      .header("User-Agent", "ponyup")
      .build()
    _http.send_request(req)

  fun ref on_connection_failure(reason: courier.ConnectionFailureReason) =>
    _notify.log(Err, "server unreachable, please try again later")

  fun ref on_parse_error(err: courier.ParseError) =>
    _notify.log(Err, "server unreachable, please try again later")

  fun ref on_response(response: courier.Response val) =>
    let total: USize =
      match response.headers.get("content-length")
      | let s: String => try s.usize()? else 0 end
      | None => 0
      end
    _dump.set_total(total)

  fun ref on_body_chunk(data: Array[U8] val) =>
    _dump.chunk(data)

  fun ref on_response_complete() =>
    _dump.finished()
    _http.close()

actor DLDump
  let _notify: PonyupNotify
  let _file_path: FilePath
  let _cb: {(String)} val
  let _file_name: String
  let _file: File
  let _digest: ssl_crypto.Digest = ssl_crypto.Digest.sha512()
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

  be set_total(total: USize) =>
    _total = total

  be chunk(bs: ByteSeq val) =>
    _progress = _progress + bs.size()
    let percent = ((_progress.f64() / _total.f64()) * 100).usize()
    if percent > _percent then
      let progress_bar = recover String end
      progress_bar.append("\r  |")
      for i in Range(0, 100, 2) do
        progress_bar.append(if i <= percent then "#" else "-" end)
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
    _cb(ssl_crypto.ToHexString(_digest.final()))
