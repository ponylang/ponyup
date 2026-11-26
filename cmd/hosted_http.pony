interface val HostedHTTP
  """
  Fetches package metadata from the selected host.
  """

  fun get(
    url: String,
    bearer: String,
    accept: String,
    cb: {(HTTPResult)} val)
    """
    Calls cb with the response or a transport error.
    """
