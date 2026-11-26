use "collections"
use "crypto"
use "files"
use http_client = "http_client"
use "net"
use "time"
use uri = "uri"

type HTTPResult is (http_client.HTTPResponse val | QueryError)
type _ResponseHandler is ({(HTTPResult)} val | DLDump)

primitive QueryError
  """
  The package source could not complete the request.
  """

class val HTTPGet
  """
  Fetches package metadata and streams archive downloads over HTTPS.
  """

  let _auth: TCPConnectAuth
  let _ssl_ctx: (SSLContext val | None)
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
    _ssl_ctx = _TrustStore(FileAuth(auth))
    _notify = notify
    _connect_timeout_ms = connect_timeout_ms
    _query_timeout_ms = query_timeout_ms
    _download_timeout_ms = download_timeout_ms

  fun get(url: String, bearer: String, accept: String, cb: {(HTTPResult)} val)
  =>
    """
    Returns the HTTP status, headers and body of a metadata request.
    """
    _request(url, bearer, accept, cb, _query_timeout_ms)

  fun download(url: String, dump: DLDump, bearer: String = "") =>
    """
    Streams a successful archive response to the checksum writer.
    """
    _request(url, bearer, "*/*", dump, _download_timeout_ms)

  fun _request(
    url: String,
    bearer: String,
    accept: String,
    handler: _ResponseHandler,
    timeout: U64)
  =>
    try
      let ssl = _ssl_ctx as SSLContext val
      let parsed = uri.ParseURI(url) as uri.URI val
      let origin = http_client.Origin.from_uri(parsed)
      if (not origin.secure) or (origin.host == "") then error end
      let path =
        match parsed.query
        | let query': String => parsed.path + "?" + query'
        else parsed.path
        end
      let req = http_client.Request.get(path)
        .header("User-Agent", "ponyup")
        .header("Accept", accept)
      if bearer != "" then req.bearer_auth(bearer) end
      _RequestConnection(
        _auth,
        ssl,
        origin,
        req.build(),
        handler,
        _notify,
        _connect_timeout_ms,
        timeout)
    else
      _notify.log(Info, "unable to initialize verified HTTPS request")
      match \exhaustive\ handler
      | let dump: DLDump => dump.failed()
      | let cb: {(HTTPResult)} val => cb(QueryError)
      end
    end

primitive _TrustStore
  fun apply(auth: FileAuth): (SSLContext val | None) =>
    ifdef windows then
      try recover val SSLContext .> set_authority(None)? end end
    else
      let paths =
        [ "/etc/ssl/certs/ca-certificates.crt"
          "/etc/ssl/cert.pem"
          "/etc/pki/tls/certs/ca-bundle.crt" ]
      for path in paths.values()
      do
        try
          let file = FilePath(auth, path)
          return recover val SSLContext .> set_authority(file)? end
        end
      end
    end

actor _RequestConnection is
  (http_client.HTTPClientConnectionActor & http_client.RedirectFollowerNotify)
  var _http: http_client.RedirectFollower = http_client.RedirectFollower.none()
  let _request: http_client.HTTPRequest val
  let _handler: _ResponseHandler
  let _notify: PonyupNotify
  let _host: String
  let _timeout_ms: U64
  let _timers: Timers = Timers
  let _collector: http_client.ResponseCollector =
    http_client.ResponseCollector
  var _done: Bool = false

  new create(
    auth: TCPConnectAuth,
    ssl: SSLContext val,
    origin: http_client.Origin,
    request: http_client.HTTPRequest val,
    handler: _ResponseHandler,
    notify: PonyupNotify,
    connect_ms: U64,
    timeout_ms: U64)
  =>
    _request = request
    _handler = handler
    _notify = notify
    _host = origin.host
    _timeout_ms = timeout_ms
    let conn_timeout =
      match MakeConnectionTimeout(connect_ms)
      | let t: ConnectionTimeout => t
      end
    let body_limit: USize =
      match handler
      | let _: DLDump => 524_288_000
      else 16_777_216
      end
    let config =
      http_client.ClientConnectionConfig(where
        max_body_size' = body_limit, connection_timeout' = conn_timeout)
    let conn =
      http_client.HTTPClientConnection.ssl(
        auth, ssl, origin.host, origin.port, this, config)
    let factory =
      {ref(target: uri.URI val)(auth, ssl, config, client = this)
        : http_client.HTTPClientConnection
      =>
        let o = http_client.Origin.from_uri(target)
        http_client.HTTPClientConnection.ssl(
          auth, ssl, o.host, o.port, client, config)
      }
    _http = http_client.RedirectFollower(conn, this, factory, 5, origin)

  fun ref _http_client_connection(): http_client.HTTPClientConnection =>
    _http.connection()

  fun ref on_connected() =>
    let owner: _RequestConnection tag = this
    _timers(Timer(
      object iso is TimerNotify
        fun ref apply(timer: Timer, count: U64): Bool =>
          owner.timed_out()
          false
      end,
      _timeout_ms * 1_000_000))
    _http.send_request(_request)

  fun ref on_response(response: http_client.Response val) =>
    if response.status >= 400 then
      _notify.log(Info, _host + " returned HTTP " + response.status.string())
    end
    match _handler
    | let dump: DLDump =>
      if response.status != 200 then
        _fail("HTTP " + response.status.string())
      else
        try
          let length = response.headers.get("content-length") as String
          dump.set_total(length.usize()?)
        end
      end
    else
      _collector.set_response(response)
    end

  fun ref on_body_chunk(data: Array[U8] val) =>
    if _done then return end
    match _handler
    | let dump: DLDump => dump.chunk(data)
    else _collector.add_chunk(data)
    end

  fun ref on_response_complete() =>
    if _done then return end
    _done = true
    _timers.dispose()
    match \exhaustive\ _handler
    | let dump: DLDump => dump.finished()
    | let cb: {(HTTPResult)} val =>
      try cb(_collector.build()?) else cb(QueryError) end
    end
    _http.connection().close()

  fun ref on_connection_failure(reason: ConnectionFailureReason) =>
    let message =
      match \exhaustive\ reason
      | ConnectionFailedDNS => "DNS resolution failed"
      | ConnectionFailedTCP => "TCP connection failed"
      | ConnectionFailedSSL => "TLS handshake failed"
      | ConnectionFailedTimeout => "connection timed out"
      | ConnectionFailedTimerError => "could not start connection timer"
      end
    _fail(message)

  fun ref on_parse_error(err: http_client.ParseError) =>
    _fail("invalid HTTP response")

  fun ref on_redirect_error(err: http_client.RedirectError) =>
    _fail("could not follow redirect")

  fun ref on_closed() => _fail("connection closed before response completed")

  be timed_out() => _fail("request timed out")

  fun ref _fail(reason: String) =>
    if _done then return end
    _done = true
    _timers.dispose()
    _notify.log(Info, _host + ": " + reason)
    match \exhaustive\ _handler
    | let dump: DLDump => dump.failed()
    | let cb: {(HTTPResult)} val => cb(QueryError)
    end
    _http.connection().close()

actor DLDump
  """
  Writes downloaded bytes to a file while computing the archive digest
  and displaying a progress bar.
  """

  let _notify: PonyupNotify
  let _file_path: FilePath
  let _cb: {(String)} val
  let _fail_cb: {()} val
  let _file_name: String
  let _file: File
  var _write_failed: Bool = false
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
    _write_failed = not _file.set_length(0)

  be set_total(total: USize) =>
    _total = total

  be chunk(bs: ByteSeq val) =>
    """
    Writes a downloaded chunk to disk and updates the progress bar.
    """
    if _write_failed then return end
    try
      if not _file.write(bs) then error end
      _digest.append(bs)?
    else
      _write_failed = true
      return
    end
    if _total == 0 then return end
    _progress = _progress + bs.size()
    let percent =
      ((_progress.f64() / _total.f64()) * 100).usize()
    if percent > _percent then
      let progress_bar = recover String end
      progress_bar.append("\r  |")
      for i in Range[USize].till(0, 100, 2) do
        progress_bar.append(
          if i <= percent then "#" else "-" end)
      end
      progress_bar .> append("| ") .> append(_file_name)
      _notify.write(consume progress_bar)
      _percent = percent
    end

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
    try
      if _write_failed then error end
      _cb(ToHexString(_digest.final()?))
    else
      _file_path.remove()
      _fail_cb()
    end
