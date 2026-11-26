import subprocess
import sys
import tempfile
from pathlib import Path


def check_isolation(runner, workdir):
    fixture_test = "--only=optional binaries - present"
    subprocess.run([runner, fixture_test], cwd=workdir, check=True)
    fixtures = workdir / ".pony_test"
    locks = list(fixtures.rglob(".lock"))
    if len(locks) != 1:
        raise AssertionError(f"{fixture_test} produced {len(locks)} lockfiles, expected one")
    first = locks[0]
    marker = first.parent / "other-runner"
    marker.write_text("in use")

    subprocess.run([runner, "--list"], cwd=workdir, check=True)
    if not marker.is_file():
        raise AssertionError("Listing tests removed another runner's fixture")

    subprocess.run([runner, fixture_test], cwd=workdir, check=True)
    if not marker.is_file() or not first.is_file():
        raise AssertionError("Running the same test removed the first fixture")
    if not any(lock != first for lock in fixtures.rglob(".lock")):
        raise AssertionError("Two executions of the same test shared a fixture")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as workdir:
        check_isolation(Path(sys.argv[1]).resolve(), Path(workdir))
