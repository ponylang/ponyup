use "collections"
use courier = "courier"
use "files"
use "json"
use ssl_crypto = "ssl/crypto"
use lori = "lori"
use ssl_net = "ssl/net"

type QueryResult is (Array[JsonObject val] iso | QueryError)

primitive QueryError
  """
  Indicates that an HTTP-level failure occurred during a Cloudsmith API query
  (connection failure, timeout, or parse error). Distinct from a successful
  query that returned zero results.
  """

class val HTTPGet
  let _auth: lori.TCPConnectAuth
  let _ssl_ctx: ssl_net.SSLContext val
  let _notify: PonyupNotify
  let _connect_timeout_ms: U64
  let _query_timeout_ms: U64
  let _download_timeout_ms: U64

  new val create(
    auth: AmbientAuth,
    notify: PonyupNotify,
    connect_timeout_ms: U64 = 30_000,
    query_timeout_ms: U64 = 15_000,
    download_timeout_ms: U64 = 300_000)
  =>
    _auth = lori.TCPConnectAuth(auth)
    _ssl_ctx = recover val ssl_net.SSLContext.>set_client_verify(false) end
    _notify = notify
    _connect_timeout_ms = connect_timeout_ms
    _query_timeout_ms = query_timeout_ms
    _download_timeout_ms = download_timeout_ms

  fun query(
    url_string: String,
    cb: {(QueryResult)} val)
  =>
    match courier.URL.parse(url_string)
    | let url: courier.ParsedURL =>
      _QueryConnection(
        _auth, _ssl_ctx, url, _notify, cb,
        _connect_timeout_ms, _query_timeout_ms)
    | let err: courier.URLParseError =>
      _notify.log(InternalErr, "invalid url: " + url_string)
      cb(QueryError)
    end

  fun download(url_string: String, dump: DLDump) =>
    match courier.URL.parse(url_string)
    | let url: courier.ParsedURL =>
      _DownloadConnection(
        _auth, _ssl_ctx, url, _notify, dump,
        _connect_timeout_ms, _download_timeout_ms)
    | let err: courier.URLParseError =>
      _notify.log(InternalErr, "invalid url: " + url_string)
      dump.failed()
    end

actor _QueryConnection is courier.HTTPClientConnectionActor
  var _http: courier.HTTPClientConnection =
    courier.HTTPClientConnection.none()
  let _notify: PonyupNotify
  let _cb: {(QueryResult)} val
  let _url: courier.ParsedURL val
  var _collector: courier.ResponseCollector = courier.ResponseCollector
  let _request_timeout_ms: U64
  var _timer: (lori.TimerToken | None) = None

  new create(
    auth: lori.TCPConnectAuth,
    ssl_ctx: ssl_net.SSLContext val,
    url: courier.ParsedURL val,
    notify: PonyupNotify,
    cb: {(QueryResult)} val,
    connect_timeout_ms: U64 = 30_000,
    request_timeout_ms: U64 = 15_000)
  =>
    _notify = notify
    _cb = cb
    _url = url
    _request_timeout_ms = request_timeout_ms
    let conn_timeout: (lori.ConnectionTimeout | None) =
      match lori.MakeConnectionTimeout(connect_timeout_ms)
      | let t: lori.ConnectionTimeout => t
      else None
      end
    _http =
      courier.HTTPClientConnection.ssl(
        auth, ssl_ctx, url.host, url.port, this,
        courier.ClientConnectionConfig(where
          connection_timeout' = conn_timeout))

  fun ref _http_client_connection(): courier.HTTPClientConnection => _http

  fun ref on_connected() =>
    _notify.log(Extra,
      "query: connected to " + _url.host + ":" + _url.port)
    let req = courier.Request.get(_url.request_path())
      .header("User-Agent", "ponyup")
      .build()
    _http.send_request(req)
    match lori.MakeTimerDuration(_request_timeout_ms)
    | let d: lori.TimerDuration =>
      match _http.set_timer(d)
      | let t: lori.TimerToken => _timer = t
      end
    end

  fun ref on_connection_failure(reason: courier.ConnectionFailureReason) =>
    _notify.log(Err,
      "query: connection to " + _url.host + " failed: " + reason.string())
    _cb(QueryError)

  fun ref on_parse_error(err: courier.ParseError) =>
    match _timer
    | let t: lori.TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    _notify.log(Err,
      "query: HTTP parse error from " + _url.host + ": " + err.string())
    _cb(QueryError)

  fun ref on_response(response: courier.Response val) =>
    _notify.log(Extra,
      "query: response " + response.status.string() + " " + response.reason)
    for (name, value) in response.headers.values() do
      _notify.log(Extra, "query: header " + name + ": " + value)
    end
    _collector = courier.ResponseCollector
    _collector.set_response(response)

  fun ref on_body_chunk(data: Array[U8] val) =>
    _collector.add_chunk(data)

  fun ref on_response_complete() =>
    match _timer
    | let t: lori.TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    let result = recover Array[JsonObject val] end
    try
      let response = _collector.build()?
      let body_str = String.from_array(response.body)
      _notify.log(Extra,
        "query: received response of size " + body_str.size().string())
      match JsonParser.parse(body_str)
      | let arr: JsonArray =>
        for v in arr.values() do
          try result.push(v as JsonObject) end
        end
      end
    end
    _cb(consume result)
    _http.close()

  fun ref on_timer(token: lori.TimerToken) =>
    match _timer
    | let t: lori.TimerToken if t == token =>
      _timer = None
      _notify.log(Err,
        "query: timed out waiting for " + _url.host
          + ", try again or increase --api-timeout")
      _cb(QueryError)
      _http.close()
    end

  fun ref on_timer_failure() =>
    _notify.log(Err,
      "query: failed to arm timeout timer for " + _url.host
        + ", aborting request")
    _cb(QueryError)
    _http.close()

actor _DownloadConnection is courier.HTTPClientConnectionActor
  var _http: courier.HTTPClientConnection =
    courier.HTTPClientConnection.none()
  let _notify: PonyupNotify
  let _dump: DLDump
  let _url: courier.ParsedURL val
  let _request_timeout_ms: U64
  var _timer: (lori.TimerToken | None) = None
  var _bytes_received: USize = 0
  var _first_chunk_logged: Bool = false

  new create(
    auth: lori.TCPConnectAuth,
    ssl_ctx: ssl_net.SSLContext val,
    url: courier.ParsedURL val,
    notify: PonyupNotify,
    dump: DLDump,
    connect_timeout_ms: U64 = 30_000,
    request_timeout_ms: U64 = 300_000)
  =>
    _notify = notify
    _dump = dump
    _url = url
    _request_timeout_ms = request_timeout_ms
    let conn_timeout: (lori.ConnectionTimeout | None) =
      match lori.MakeConnectionTimeout(connect_timeout_ms)
      | let t: lori.ConnectionTimeout => t
      else None
      end
    _http =
      courier.HTTPClientConnection.ssl(
        auth, ssl_ctx, url.host, url.port, this,
        courier.ClientConnectionConfig(where
          max_body_size' = 524_288_000,
          connection_timeout' = conn_timeout))

  fun ref _http_client_connection(): courier.HTTPClientConnection => _http

  fun ref on_connected() =>
    _notify.log(Extra,
      "download: connected to " + _url.host + ":" + _url.port)
    let req = courier.Request.get(_url.request_path())
      .header("User-Agent", "ponyup")
      .build()
    _http.send_request(req)
    match lori.MakeTimerDuration(_request_timeout_ms)
    | let d: lori.TimerDuration =>
      match _http.set_timer(d)
      | let t: lori.TimerToken => _timer = t
      end
    end

  fun ref on_connection_failure(reason: courier.ConnectionFailureReason) =>
    _notify.log(Err,
      "download: connection to " + _url.host + " failed: "
        + reason.string())
    _dump.failed()

  fun ref on_parse_error(err: courier.ParseError) =>
    match _timer
    | let t: lori.TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    _notify.log(Err,
      "download: HTTP parse error from " + _url.host + ": " + err.string())
    _dump.failed()

  fun ref on_response(response: courier.Response val) =>
    _notify.log(Extra,
      "download: response " + response.status.string()
        + " " + response.reason)
    for (name, value) in response.headers.values() do
      _notify.log(Extra, "download: header " + name + ": " + value)
    end
    let total: USize =
      match response.headers.get("content-length")
      | let s: String => try s.usize()? else 0 end
      | None => 0
      end
    _notify.log(Extra, "download: content-length=" + total.string())
    _dump.set_total(total)

  fun ref on_body_chunk(data: Array[U8] val) =>
    _bytes_received = _bytes_received + data.size()
    if not _first_chunk_logged then
      _first_chunk_logged = true
      _notify.log(Extra,
        "download: first chunk received, " + data.size().string() + " bytes")
    end
    _dump.chunk(data)

  fun ref on_response_complete() =>
    match _timer
    | let t: lori.TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    _notify.log(Extra,
      "download: complete, " + _bytes_received.string()
        + " total bytes received")
    _dump.finished()
    _http.close()

  fun ref on_timer(token: lori.TimerToken) =>
    match _timer
    | let t: lori.TimerToken if t == token =>
      _timer = None
      _notify.log(Err,
        "download: timed out after receiving " + _bytes_received.string()
          + " bytes from " + _url.host
          + ", try again or increase --download-timeout")
      _dump.failed()
      _http.close()
    end

  fun ref on_timer_failure() =>
    _notify.log(Err,
      "download: failed to arm timeout timer for " + _url.host
        + ", aborting download")
    _dump.failed()
    _http.close()

actor DLDump
  let _notify: PonyupNotify
  let _file_path: FilePath
  let _cb: {(String)} val
  let _fail_cb: {()} val
  let _file_name: String
  let _file: File
  let _digest: ssl_crypto.Digest = ssl_crypto.Digest.sha512()
  var _total: USize = 0
  var _progress: USize = 0
  var _percent: USize = 0

  new create(
    notify: PonyupNotify,
    file_path: FilePath,
    cb: {(String)} val,
    fail_cb: {()} val = {() => None})
  =>
    _notify = consume notify
    _file_path = consume file_path
    _cb = consume cb
    _fail_cb = consume fail_cb

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

  be failed() =>
    """
    Called when the download fails (connection failure, parse error, or
    timeout). Cleans up the partial download file and notifies the caller.
    """
    _file.dispose()
    _file_path.remove()
    _fail_cb()

  be finished() =>
    _file.dispose()
    _notify.write("\n")
    _cb(ssl_crypto.ToHexString(_digest.final()))
