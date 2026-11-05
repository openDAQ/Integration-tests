"""Resolves the openDAQ, LTStreamingModulesModern and OpcUaModules refs of a run to commit SHAs.

Each ref comes from its environment variable (the workflow inputs) or else from the repo's ref file, and can be a
branch, a tag, a ref such as pull/1363/head, or a full commit SHA. The SHAs are written as the step outputs
<prefix>-sha, and the tested commits of all four repositories are reported in one notice annotation. A ref that
names no commit fails the step with an error annotation.
"""

import os
import pathlib
import re
import subprocess
import sys
import tempfile

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Name, GitHub repository, ref file, environment variable with the requested ref, prefix of the step outputs
REPOSITORIES = [
    ("openDAQ", "openDAQ/openDAQ", "opendaq_ref", "OPENDAQ_REF", "opendaq"),
    ("LTStreamingModulesModern", "openDAQ/LTStreamingModulesModern", "lt_modules_ref", "LT_MODULES_REF", "lt-modules"),
    ("OpcUaModules", "openDAQ/OpcUaModules", "opcua_modules_ref", "OPCUA_MODULES_REF", "opcua-modules"),
]

FULL_SHA = re.compile(r"[0-9a-f]{40}")
# Refs worth naming when a commit is found at them: branches, tags and pull request heads
NAMED_REF = re.compile(r"refs/heads/.+|refs/tags/.+|refs/pull/\d+/head")


def escape_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def annotate(level, title, message):
    print(f"::{level} title={escape_property(title)}::{escape_data(message)}", flush=True)


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()


def describe(ref):
    """Readable name of a full ref, e.g. branch main, tag v3.40.3 or PR #1363"""
    for pattern, text in ((r"refs/heads/(.+)", "branch {}"), (r"refs/tags/(.+)", "tag {}"),
                          (r"refs/pull/(\d+)/(?:head|merge)", "PR #{}")):
        match = re.fullmatch(pattern, ref)
        if match:
            return text.format(match.group(1))
    return ref


def remote_refs(url):
    """{full ref: commit SHA} of a remote repository, with annotated tags peeled to their commits"""
    refs = {}
    for line in git("ls-remote", url).splitlines():
        sha, ref = line.split("\t")
        if ref.endswith("^{}"):
            refs[ref[:-3]] = sha
        else:
            refs.setdefault(ref, sha)
    return refs


def commit_exists(url, sha):
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as directory:
        git("init", "--quiet", "--bare", directory)
        fetch = ["git", "-C", directory, "fetch", "--quiet", "--depth", "1", "--filter=tree:0", url, sha]
        return subprocess.run(fetch, capture_output=True).returncode == 0


def resolve(url, ref, refs):
    """(commit SHA, line text) of a ref, or None when it names no commit; refs are tried in the order git uses"""
    for candidate in (ref, f"refs/{ref}", f"refs/tags/{ref}", f"refs/heads/{ref}"):
        if candidate in refs:
            sha = refs[candidate]
            others = [describe(r) for r, s in refs.items() if s == sha and r != candidate and NAMED_REF.fullmatch(r)]
            return sha, f"{describe(candidate)} at {sha}" + (f" (also {', '.join(others)})" if others else "")
    if FULL_SHA.fullmatch(ref) and commit_exists(url, ref):
        tips = [describe(r) for r, s in refs.items() if s == ref and NAMED_REF.fullmatch(r)]
        return ref, f"commit {ref} " + (f"(tip of {', '.join(tips)})" if tips else "(not the tip of any branch, tag or PR)")
    return None


def integration_tests_line():
    """This repository's tested commit: the pull request head on pull request runs, otherwise the run's commit"""
    sha = os.environ.get("INTEGRATION_TESTS_SHA") or git("-C", str(REPO_ROOT), "rev-parse", "HEAD")
    ref = os.environ.get("GITHUB_REF") or "refs/heads/" + git("-C", str(REPO_ROOT), "branch", "--show-current")
    text = describe(ref)
    if os.environ.get("GITHUB_HEAD_REF"):
        text += f" from branch {os.environ['GITHUB_HEAD_REF']}"
    text += f" at {sha}"
    if os.environ.get("GITHUB_BASE_REF"):
        text += f" (merged into {os.environ['GITHUB_BASE_REF']})"
    return f"Integration-tests: {text}"


def main():
    lines, outputs, failed = [], [], False
    for name, repository, ref_file, variable, prefix in REPOSITORIES:
        ref = os.environ.get(variable, "").strip() or (REPO_ROOT / ref_file).read_text().strip()
        url = f"https://github.com/{repository}.git"
        try:
            resolved = resolve(url, ref, remote_refs(url)) if ref else None
        except subprocess.CalledProcessError as error:
            annotate("error", f"{name}: cannot read {repository}", error.stderr.strip())
            failed = True
            continue
        if resolved is None:
            annotate("error", f"{name}: no commit",
                     f'"{ref}" is not a branch, tag or full 40-character commit SHA of {repository}')
            failed = True
            continue
        sha, line = resolved
        lines.append(f"{name}: {line}")
        outputs.append(f"{prefix}-sha={sha}")

    if failed:
        return 1

    lines.append(integration_tests_line())
    annotate("notice", "Tested commits", "\n".join(lines))
    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as file:
            file.write("".join(f"{output}\n" for output in outputs))
    else:
        print("\n".join(outputs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
