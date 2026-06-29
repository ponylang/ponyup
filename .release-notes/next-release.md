## Fix response never arriving after sending a large request

After sending a large request, a connection could stop receiving the server's response — the response would never arrive and the request would hang indefinitely. No error was raised and the connection was not closed; it simply went quiet, even though the server had already replied. This most often showed up on connections that pushed a large request body, such as uploads. Responses now arrive as expected.

## Remove support for Alpine 3.21

We no longer support Alpine 3.21. Alpine 3.23 and 3.24 are still supported.

## Remove support for Alpine 3.22

We no longer support Alpine 3.22. Alpine 3.23 and 3.24 are still supported.

## Remove support for Ubuntu 22.04

We no longer support Ubuntu 22.04. Ubuntu 24.04 and 26.04 are still supported.

