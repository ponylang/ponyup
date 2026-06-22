## Fix response never arriving after sending a large request

After sending a large request, a connection could stop receiving the server's response — the response would never arrive and the request would hang indefinitely. No error was raised and the connection was not closed; it simply went quiet, even though the server had already replied. This most often showed up on connections that pushed a large request body, such as uploads. Responses now arrive as expected.

