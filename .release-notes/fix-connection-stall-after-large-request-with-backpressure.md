## Fix connection stall after large request with backpressure

HTTP connections could stop processing incoming data after completing a large write that triggered backpressure, causing the connection to hang.
