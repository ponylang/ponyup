## Fix incorrect FreeBSD to Cloudsmith package mapping

Ponyup now searches for FreeBSD packages on Cloudsmith using the `unknown` vendor field. This field was previously left out, resulting in failed queries.
