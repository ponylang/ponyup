## Download releases and nightly builds from GitHub by default

Ponyup now downloads releases from GitHub Releases and nightly builds from the GitHub Container Registry. Existing commands such as `ponyup update ponyc release` use the new source automatically.

Ponyup looks up releases anonymously by default. GitHub allows 60 anonymous REST API requests per hour per IP address. If you reach that limit, you can use your account’s allowance, typically 5,000 requests per hour. Sign in once with `gh auth login --hostname github.com`, then pass the token to ponyup. See [GitHub’s REST API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

On Linux or macOS, use the token for one command.

```sh
GITHUB_TOKEN="$(gh auth token --hostname github.com)" ponyup update ponyc release
```

In PowerShell, set the token for the current session.

```powershell
$env:GITHUB_TOKEN = gh auth token --hostname github.com
ponyup update ponyc release
```

The installers also use `GITHUB_TOKEN` for GitHub release lookups when it is set. Nightly lookups use anonymous access.

Cloudsmith is still available as a fallback. Pass `--source=cloudsmith` for the command that should use it.

```bash
ponyup --source=cloudsmith find ponyc release
```

## Run the selected version of ponyup on Windows

After selecting a different ponyup version on Windows, running `ponyup` could still start the executable from the original installation. The installer now creates a `ponyup.bat` launcher so the next `ponyup` command runs the selected version. In PowerShell, use `ponyup`. In batch scripts, replace calls to `bin\ponyup.exe` with `call ponyup ...` so the script continues after ponyup exits.
