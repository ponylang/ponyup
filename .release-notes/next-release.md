## Fix downloads hanging after completion

Downloading a package could hang after all data had been received, leaving ponyup stuck until killed.

## Fix downloads failing on macOS

On macOS, downloading a package could fail when connecting to a host that resolves to more than one address. Cloudsmith, where ponyup downloads packages from, is one such host. Linux and Windows were not affected.

## Fix HTTPS downloads silently losing data or failing

Several bugs in HTTPS connection handling could cause downloads to fail, data to be silently dropped, or one connection's failure to break a different connection. These could show up as unexplained download failures or checksum mismatches.
