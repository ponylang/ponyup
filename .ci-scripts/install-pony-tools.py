import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def get(url, token=None, accept=None):
    request = urllib.request.Request(url)
    if token:
        request.add_unredirected_header("Authorization", f"Bearer {token}")
    if accept:
        request.add_header("Accept", accept)
    return urllib.request.urlopen(request, timeout=120)


def release(tool, filename):
    base = f"https://api.github.com/repos/ponylang/{tool}/releases"
    url = base + "/latest"
    while url:
        if url == base + "/latest":
            try:
                with get(url) as response:
                    releases = [json.load(response)]
            except urllib.error.HTTPError as err:
                if err.code != 404:
                    raise
                releases = []
            url = base + "?per_page=20"
        else:
            with get(url) as response:
                releases = json.load(response)
                link = re.search(r'<([^>]+)>; rel="next"', response.headers.get("Link", ""))
                url = link[1] if link else None
        for item in releases:
            if item["prerelease"] or item["draft"]:
                continue
            assets = {a["name"]: a for a in item["assets"] if a["state"] == "uploaded"}
            if filename in assets and filename + ".sha512" in assets:
                with get(assets[filename + ".sha512"]["browser_download_url"]) as checksum:
                    digest = checksum.read(256).decode("ascii").strip()
                if not re.fullmatch(r"[0-9a-f]{128}", digest):
                    raise ValueError(f"Invalid SHA-512 checksum for {filename}")
                return assets[filename]["browser_download_url"], "sha512", digest, None
    raise ValueError(f"No release contains {filename}")


def nightly(tool, triple, filename):
    repo = f"ponylang/nightly/{tool}-{triple}"
    base = f"https://ghcr.io/v2/{repo}"
    query = urllib.parse.urlencode({"service": "ghcr.io", "scope": f"repository:{repo}:pull"})
    with get(f"https://ghcr.io/token?{query}") as response:
        token = json.load(response)["token"]

    url = f"{base}/tags/list?n=100"
    newest = ""
    while url:
        with get(url, token) as response:
            for tag in json.load(response)["tags"]:
                if re.fullmatch(r"[0-9]{8}", tag) and tag > newest:
                    newest = tag
            link = re.search(r'<([^>]+)>; rel="next"', response.headers.get("Link", ""))
        url = urllib.parse.urljoin(url, link[1]) if link else None
        if url and not url.startswith(f"{base}/tags/list?"):
            raise ValueError(f"Unexpected pagination URL for {repo}")
    if not newest:
        raise ValueError(f"No nightly tags for {repo}")
    accept = "application/vnd.oci.image.manifest.v1+json"
    with get(f"{base}/manifests/{newest}", token, accept) as response:
        manifest = json.load(response)
    layer, = manifest["layers"]
    if (manifest["artifactType"] != "application/vnd.ponylang.nightly.v1"
            or layer["annotations"]["org.opencontainers.image.title"] != filename):
        raise ValueError(f"Unexpected archive in manifest for {filename}")
    digest = layer["digest"]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError(f"Invalid archive digest for {filename}")
    return f"{base}/blobs/{digest}", "sha256", digest[7:], token


def install(tool, channel, triple, dest, windows):
    extension = ".zip" if windows else ".tar.gz"
    filename = f"{tool}-{triple}{extension}"
    if channel == "release":
        url, algorithm, digest, token = release(tool, filename)
    else:
        url, algorithm, digest, token = nightly(tool, triple, filename)
    print(f"Installing {filename} ({channel}) in {dest}", flush=True)
    with tempfile.TemporaryDirectory() as temp:
        archive = Path(temp) / filename
        hasher = hashlib.new(algorithm)
        with get(url, token) as response, archive.open("wb") as target:
            while chunk := response.read(1024 * 1024):
                target.write(chunk)
                hasher.update(chunk)
        if hasher.hexdigest() != digest:
            raise ValueError(f"Checksum mismatch for {filename}")
        dest.mkdir(parents=True, exist_ok=True)
        extract = ["tar", "-xf", str(archive), "-C", str(dest)]
        if not windows:
            extract.append("--strip-components=1")
        subprocess.run(extract, check=True)


def main():
    args = argparse.ArgumentParser()
    args.add_argument("platform")
    args.add_argument("ponyc", choices=["release", "nightly"])
    args.add_argument("corral", choices=["release", "nightly"])
    options = args.parse_args()
    triple = options.platform.replace("x86_64", "x86-64")
    if "-linux" in triple and "-unknown-linux" not in triple:
        triple = triple.replace("-linux", "-unknown-linux")
    elif triple.endswith("-darwin") and not triple.endswith("-apple-darwin"):
        triple = triple.removesuffix("-darwin") + "-apple-darwin"
    windows = triple.endswith("-pc-windows-msvc")
    for tool in ("ponyc", "corral"):
        tool_triple = triple if tool == "ponyc" else re.sub(r"(-unknown-linux)-.*", r"\1", triple)
        dest = Path(r"C:\ponyc") if windows else Path("/tmp") / tool
        install(tool, getattr(options, tool), tool_triple, dest, windows)


if __name__ == "__main__":
    main()
