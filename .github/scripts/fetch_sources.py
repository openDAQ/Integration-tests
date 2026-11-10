"""Fetches openDAQ, LTStreamingModulesModern and OpcUaModules at given commits into build/_src/<name>.

Runs as the packages "run" command of openDAQ-CI's reusable workflow, before Configure; the workflow's cmake-presets
point FETCHCONTENT_SOURCE_DIR_<NAME> at the folders. Each commit is fetched alone (depth 1), as actions/checkout does,
so every commit GitHub serves works: branches, tags, pull request heads and merge commits, also from forks. The command
runs in bash on Linux and macOS and in PowerShell on Windows, so this is a Python script rather than shell commands.
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys
import time

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Name (also the folder), GitHub repository, command line option
REPOSITORIES = [
    ("openDAQ", "openDAQ/openDAQ", "opendaq"),
    ("LTStreamingModulesModern", "openDAQ/LTStreamingModulesModern", "lt-modules"),
    ("OpcUaModules", "openDAQ/OpcUaModules", "opcua-modules"),
]

FULL_SHA = re.compile(r"[0-9a-f]{40}")
FETCH_ATTEMPTS = 3


def escape_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def annotate(level, title, message):
    print(f"::{level} title={escape_property(title)}::{escape_data(message)}", flush=True)


def git(*args):
    print("git " + " ".join(args), flush=True)
    subprocess.run(["git", *args], check=True)


def fetch(url, sha, folder):
    """Checks out the commit in the folder; a folder from an earlier run is reused and overwritten"""
    git("init", "--quiet", str(folder))
    for attempt in range(1, FETCH_ATTEMPTS + 1):
        try:
            git("-C", str(folder), "fetch", "--quiet", "--no-tags", "--depth", "1", url, sha)
            break
        except subprocess.CalledProcessError:
            if attempt == FETCH_ATTEMPTS:
                raise
            print(f"The fetch failed, trying again in {10 * attempt} s", flush=True)
            time.sleep(10 * attempt)
    git("-C", str(folder), "checkout", "--quiet", "--force", "--detach", "FETCH_HEAD")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    for _, repository, option in REPOSITORIES:
        parser.add_argument(f"--{option}", required=True, metavar="SHA", help=f"full commit SHA of {repository}")
    parser.add_argument("--dest", type=pathlib.Path, default=REPO_ROOT / "build" / "_src",
                        help="folder that gets one subfolder per repository (default: build/_src of this repository)")
    args = parser.parse_args()

    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    for name, repository, option in REPOSITORIES:
        sha = getattr(args, option.replace("-", "_"))
        if not FULL_SHA.fullmatch(sha):
            annotate("error", f"{name}: no commit", f'"{sha}" is not a full 40-character commit SHA of {repository}')
            return 1
        print(f"::group::{name} at {sha}", flush=True)
        try:
            fetch(f"{server}/{repository}.git", sha, args.dest / name)
        except subprocess.CalledProcessError:
            annotate("error", f"{name}: fetch failed", f"Cannot fetch commit {sha} of {repository}; the log has git's output")
            return 1
        finally:
            print("::endgroup::", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
