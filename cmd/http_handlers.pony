use "collections"
use http_client = "http_client"
use "files"
use "json"
use "crypto"
use "net"

use uri = "uri"

type QueryResult is (Array[JSONObject val] iso | QueryError)

primitive QueryError
  """
  Indicates that an HTTP-level failure occurred during a Cloudsmith API
  query (connection failure, timeout, or parse error). Distinct from a
  successful query that returned zero results.
  """

class val HTTPGet
  """
  Performs HTTPS requests against the Cloudsmith API for package queries
  and downloads.
  """

  let _auth: TCPConnectAuth
  let _ssl_ctx: SSLContext val
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
    _auth = TCPConnectAuth(auth)
    _ssl_ctx =
      recover val SSLContext .> set_client_verify(false) end
    _notify = notify
    _connect_timeout_ms = connect_timeout_ms
    _query_timeout_ms = query_timeout_ms
    _download_timeout_ms = download_timeout_ms

  fun query(
    url_string: String,
    cb: {(QueryResult)} val)
  =>
    match \exhaustive\ uri.ParseURI(url_string)
    | let parsed: uri.URI val =>
      match parsed.authority
      | let auth: uri.URIAuthority =>
        let port =
          match \exhaustive\ auth.port
          | let p: U16 => p.string()
          | None => "443"
          end
        var request_path: String = parsed.path
        match parsed.query
        | let q: String =>
          request_path = request_path + "?" + q
        end
        _QueryConnection(
          _auth,
          _ssl_ctx,
          auth.host,
          port,
          request_path,
          _notify,
          cb,
          _connect_timeout_ms,
          _query_timeout_ms)
      else
        _notify.log(InternalErr, "invalid url: " + url_string)
        cb(QueryError)
      end
    | let _: uri.URIParseError val =>
      _notify.log(InternalErr, "invalid url: " + url_string)
      cb(QueryError)
    end

  fun download(url_string: String, dump: DLDump) =>
    match \exhaustive\ uri.ParseURI(url_string)
    | let parsed: uri.URI val =>
      match parsed.authority
      | let auth: uri.URIAuthority =>
        let port =
          match \exhaustive\ auth.port
          | let p: U16 => p.string()
          | None => "443"
          end
        var request_path: String = parsed.path
        match parsed.query
        | let q: String =>
          request_path = request_path + "?" + q
        end
        _DownloadConnection(
          _auth,
          _ssl_ctx,
          auth.host,
          port,
          request_path,
          _notify,
          dump,
          _connect_timeout_ms,
          _download_timeout_ms)
      else
        _notify.log(InternalErr, "invalid url: " + url_string)
        dump.failed()
      end
    | let _: uri.URIParseError val =>
      _notify.log(InternalErr, "invalid url: " + url_string)
      dump.failed()
    end

actor _QueryConnection is http_client.HTTPClientConnectionActor
  var _http: http_client.HTTPClientConnection =
    http_client.HTTPClientConnection.none()
  let _notify: PonyupNotify
  let _cb: {(QueryResult)} val
  let _host: String
  let _request_path: String
  var _collector: http_client.ResponseCollector =
    http_client.ResponseCollector
  let _request_timeout_ms: U64
  var _timer: (TimerToken | None) = None

  new create(
    auth: TCPConnectAuth,
    ssl_ctx: SSLContext val,
    host: String,
    port: String,
    request_path: String,
    notify: PonyupNotify,
    cb: {(QueryResult)} val,
    connect_timeout_ms: U64 = 30_000,
    request_timeout_ms: U64 = 15_000)
  =>
    _notify = notify
    _cb = cb
    _host = host
    _request_path = request_path
    _request_timeout_ms = request_timeout_ms
    let conn_timeout: (ConnectionTimeout | None) =
      match MakeConnectionTimeout(connect_timeout_ms)
      | let t: ConnectionTimeout => t
      else None
      end
    _http =
      http_client.HTTPClientConnection.ssl(
        auth,
        ssl_ctx,
        host,
        port,
        this,
        http_client.ClientConnectionConfig(where
          connection_timeout' = conn_timeout))

  fun ref _http_client_connection()
    : http_client.HTTPClientConnection
  =>
    _http

  fun ref on_connected() =>
    _notify.log(
      Extra,
      "query: connected to " + _host)
    let req = http_client.Request.get(_request_path)
      .header("User-Agent", "ponyup")
      .build()
    _http.send_request(req)
    match MakeTimerDuration(_request_timeout_ms)
    | let d: TimerDuration =>
      match _http.set_timer(d)
      | let t: TimerToken => _timer = t
      end
    end

  fun ref on_connection_failure(
    reason: ConnectionFailureReason)
  =>
    let reason_str =
      match \exhaustive\ reason
      | ConnectionFailedDNS => "DNS resolution failed"
      | ConnectionFailedTCP => "TCP connection failed"
      | ConnectionFailedSSL => "SSL handshake failed"
      | ConnectionFailedTimeout => "connection timed out"
      | ConnectionFailedTimerError =>
        "connect timer failed"
      end
    _notify.log(
      Err,
      "query: connection to " + _host +
        " failed: " + reason_str)
    _cb(QueryError)

  fun ref on_parse_error(err: http_client.ParseError) =>
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    let err_str =
      match \exhaustive\ err
      | http_client.TooLarge => "response too large"
      | http_client.InvalidStatusLine => "invalid status line"
      | http_client.InvalidVersion => "invalid HTTP version"
      | http_client.MalformedHeaders => "malformed headers"
      | http_client.InvalidContentLength =>
        "invalid content-length"
      | http_client.InvalidChunk => "invalid chunk encoding"
      | http_client.BodyTooLarge => "body too large"
      end
    _notify.log(
      Err,
      "query: HTTP parse error from " + _host +
        ": " + err_str)
    _cb(QueryError)

  fun ref on_response(response: http_client.Response val) =>
    _notify.log(
      Extra,
      "query: response " + response.status.string() +
        " " + response.reason)
    for (name, value) in response.headers.values() do
      _notify.log(Extra, "query: header " + name + ": " + value)
    end
    _collector = http_client.ResponseCollector
    _collector.set_response(response)

  fun ref on_body_chunk(data: Array[U8] val) =>
    _collector.add_chunk(data)

  fun ref on_response_complete() =>
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    let result = recover Array[JSONObject val] end
    try
      let response = _collector.build()?
      let body_str = String.from_array(response.body)
      _notify.log(
        Extra,
        "query: received response of size " +
          body_str.size().string())
      match JSONParser.parse(body_str)
      | let arr: JSONArray =>
        for v in arr.values() do
          try result.push(v as JSONObject) end
        end
      end
    end
    _cb(consume result)
    _http.close()

  fun ref on_timer(token: TimerToken) =>
    match _timer
    | let t: TimerToken if t == token =>
      _timer = None
      _notify.log(
        Err,
        "query: timed out waiting for " + _host +
          ", try again or increase --api-timeout")
      _cb(QueryError)
      _http.close()
    end

  fun ref on_timer_failure() =>
    _notify.log(
      Err,
      "query: failed to arm timeout timer for " + _host +
        ", aborting request")
    _cb(QueryError)
    _http.close()

actor _DownloadConnection is http_client.HTTPClientConnectionActor
  var _http: http_client.HTTPClientConnection =
    http_client.HTTPClientConnection.none()
  let _notify: PonyupNotify
  let _dump: DLDump
  let _host: String
  let _request_path: String
  let _request_timeout_ms: U64
  var _timer: (TimerToken | None) = None
  var _bytes_received: USize = 0
  var _first_chunk_logged: Bool = false

  new create(
    auth: TCPConnectAuth,
    ssl_ctx: SSLContext val,
    host: String,
    port: String,
    request_path: String,
    notify: PonyupNotify,
    dump: DLDump,
    connect_timeout_ms: U64 = 30_000,
    request_timeout_ms: U64 = 300_000)
  =>
    _notify = notify
    _dump = dump
    _host = host
    _request_path = request_path
    _request_timeout_ms = request_timeout_ms
    let conn_timeout: (ConnectionTimeout | None) =
      match MakeConnectionTimeout(connect_timeout_ms)
      | let t: ConnectionTimeout => t
      else None
      end
    _http =
      http_client.HTTPClientConnection.ssl(
        auth,
        ssl_ctx,
        host,
        port,
        this,
        http_client.ClientConnectionConfig(where
          max_body_size' = 524_288_000,
          connection_timeout' = conn_timeout))

  fun ref _http_client_connection()
    : http_client.HTTPClientConnection
  =>
    _http

  fun ref on_connected() =>
    _notify.log(
      Extra,
      "download: connected to " + _host)
    let req = http_client.Request.get(_request_path)
      .header("User-Agent", "ponyup")
      .build()
    _http.send_request(req)
    match MakeTimerDuration(_request_timeout_ms)
    | let d: TimerDuration =>
      match _http.set_timer(d)
      | let t: TimerToken => _timer = t
      end
    end

  fun ref on_connection_failure(
    reason: ConnectionFailureReason)
  =>
    let reason_str =
      match \exhaustive\ reason
      | ConnectionFailedDNS => "DNS resolution failed"
      | ConnectionFailedTCP => "TCP connection failed"
      | ConnectionFailedSSL => "SSL handshake failed"
      | ConnectionFailedTimeout => "connection timed out"
      | ConnectionFailedTimerError =>
        "connect timer failed"
      end
    _notify.log(
      Err,
      "download: connection to " + _host + " failed: " +
        reason_str)
    _dump.failed()

  fun ref on_parse_error(err: http_client.ParseError) =>
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    let err_str =
      match \exhaustive\ err
      | http_client.TooLarge => "response too large"
      | http_client.InvalidStatusLine => "invalid status line"
      | http_client.InvalidVersion => "invalid HTTP version"
      | http_client.MalformedHeaders => "malformed headers"
      | http_client.InvalidContentLength =>
        "invalid content-length"
      | http_client.InvalidChunk => "invalid chunk encoding"
      | http_client.BodyTooLarge => "body too large"
      end
    _notify.log(
      Err,
      "download: HTTP parse error from " + _host +
        ": " + err_str)
    _dump.failed()

  fun ref on_response(response: http_client.Response val) =>
    _notify.log(
      Extra,
      "download: response " + response.status.string() +
        " " + response.reason)
    for (name, value) in response.headers.values() do
      _notify.log(
        Extra, "download: header " + name + ": " + value)
    end
    let total: USize =
      match \exhaustive\ response.headers.get("content-length")
      | let s: String => try s.usize()? else 0 end
      | None => 0
      end
    _notify.log(
      Extra, "download: content-length=" + total.string())
    _dump.set_total(total)

  fun ref on_body_chunk(data: Array[U8] val) =>
    _bytes_received = _bytes_received + data.size()
    if not _first_chunk_logged then
      _first_chunk_logged = true
      _notify.log(
        Extra,
        "download: first chunk received, " +
          data.size().string() + " bytes")
    end
    _dump.chunk(data)

  fun ref on_response_complete() =>
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    _notify.log(
      Extra,
      "download: complete, " + _bytes_received.string() +
        " total bytes received")
    _dump.finished()
    _http.close()

  fun ref on_timer(token: TimerToken) =>
    match _timer
    | let t: TimerToken if t == token =>
      _timer = None
      _notify.log(
        Err,
        "download: timed out after receiving " +
          _bytes_received.string() +
          " bytes from " + _host +
          ", try again or increase --download-timeout")
      _dump.failed()
      _http.close()
    end

  fun ref on_timer_failure() =>
    _notify.log(
      Err,
      "download: failed to arm timeout timer for " + _host +
        ", aborting download")
    _dump.failed()
    _http.close()

actor DLDump
  """
  Writes downloaded bytes to a file while computing a SHA-512 digest
  and displaying a progress bar.
  """

  let _notify: PonyupNotify
  let _file_path: FilePath
  let _cb: {(String)} val
  let _fail_cb: {()} val
  let _file_name: String
  let _file: File
  let _digest: Digest
  var _total: USize = 0
  var _progress: USize = 0
  var _percent: USize = 0

  new create(
    notify: PonyupNotify,
    file_path: FilePath,
    cb: {(String)} val,
    digest: Digest iso,
    fail_cb: {()} val = {() => None })
  =>
    _notify = consume notify
    _file_path = consume file_path
    _cb = consume cb
    _fail_cb = consume fail_cb
    _digest = consume digest

    let components = _file_path.path.split("/")
    _file_name =
      try components(components.size() - 1)? else "" end
    _file = File(_file_path)

  be set_total(total: USize) =>
    _total = total

  be chunk(bs: ByteSeq val) =>
    """
    Writes a downloaded chunk to disk and updates the progress bar.
    """
    _progress = _progress + bs.size()
    let percent =
      ((_progress.f64() / _total.f64()) * 100).usize()
    if percent > _percent then
      let progress_bar = recover String end
      progress_bar.append("\r  |")
      for i in Range(0, 100, 2) do
        progress_bar.append(
          if i <= percent then "#" else "-" end)
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
    timeout). Cleans up the partial download file and notifies the
    caller.
    """
    _file.dispose()
    _file_path.remove()
    _fail_cb()

  be finished() =>
    """
    Called when the download completes. Computes the final digest hash
    and passes it to the completion callback.
    """
    _file.dispose()
    _notify.write("\n")
    let hash =
      try ToHexString(_digest.final()?) else "" end
    _cb(hash)
