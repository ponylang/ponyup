import io
import json
import os
import runpy
import unittest
import urllib.request
from pathlib import Path
from unittest.mock import patch


release = runpy.run_path(str(Path(__file__).with_name("install-pony-tools.py")))["release"]
base = "https://api.github.com/repos/ponylang/corral/releases"
first = base + "?per_page=20"
next_page = "https://api.github.com/repositories/96358645/releases?page=2"
archive = "https://github.com/ponylang/corral/releases/download/1/corral.zip"


def page(items, next_url=None):
    response = io.BytesIO(json.dumps(items).encode())
    response.headers = {"Link": f'<{next_url}>; rel="next"'} if next_url else {}
    return response


class ReleaseRequests(unittest.TestCase):
    def test_credentials_on_metadata_requests(self):
        assets = [
            {"name": "corral.zip" + suffix, "state": "uploaded", "browser_download_url": archive + suffix}
            for suffix in ("", ".sha512")
        ]
        item = {"draft": False, "prerelease": False, "assets": assets}
        for token in ("", "job-token"):
            with self.subTest(token=token), patch.dict(os.environ, GITHUB_TOKEN=token):
                responses = [page(dict(item, assets=[])), page([], next_page), page([item]), io.BytesIO(b"a" * 128)]
                with patch.object(urllib.request, "urlopen", side_effect=responses) as fetch:
                    url, _, _, download_token = release("corral", "corral.zip")
                self.assertEqual(url, archive)
                self.assertIsNone(download_token)
                auth = f"Bearer {token}" if token else None
                requests = [(r.args[0].full_url, r.args[0].get_header("Authorization")) for r in fetch.call_args_list]
                self.assertEqual(requests, [
                    (base + "/latest", auth), (first, auth), (next_page, auth), (archive + ".sha512", None)
                ])

    def test_rejects_off_site_release_pagination(self):
        responses = [page({"draft": True, "prerelease": False}), page([], "https://example.org/releases?page=2")]
        with patch.dict(os.environ, GITHUB_TOKEN="job-token"):
            with patch.object(urllib.request, "urlopen", side_effect=responses) as fetch:
                with self.assertRaisesRegex(ValueError, "Unexpected release pagination URL"):
                    release("corral", "corral.zip")
        self.assertEqual(fetch.call_count, 2)


if __name__ == "__main__":
    unittest.main()
