## Fix incorrect FreeBSD to Cloudsmith package mapping

Ponyup now searches for FreeBSD packages on Cloudsmith using the `unknown` vendor field. This field was previously left out, resulting in failed queries.
## Switch support FreeBSD version

We've switched our supported FreeBSD from 12.1 to 12.2. The switch means that FreeBSD packages are tested and built on FreeBSD 12.2 and we no longer do any testing or building on 12.1.

You can continue using ponyup on FreeBSD 12.1 but we make no guarantees that it will work.

