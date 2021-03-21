## Fix segfault in prebuilt Linux ponyup releases

There was a bug in the Pony runtime related to opening sockets that could cause a segfault. The bug was fixed a few months ago, but our Linux ponyup releases were still being built with an older version (aka still with the bug) of the Pony runtime due to a stale build environment.

