"""Checks the stagings that the caller of integration-tests-prebuilt.yml uploaded to the run (staging-source "run"),
and gives their full commits.

The artifacts are downloaded with actions/download-artifact by pattern, so each one is a folder named after it,
<dir>/<component>-staging-<job>/. openDAQ-CI's stage puts a staging into a subfolder named after it
(<staging>/: core, opcua, lt-streaming) with one .tar.gz and its staging-meta.json; any depth is taken, the
artifact's root too. Each staging has to:
- be there, with exactly one staging-meta.json and exactly one tarball, beside each other;
- name its component and the build job's triplet in staging-meta.json;
- for a module, be built against the core of the run: dependencies.opendaq.revision is that core's full commit.

The commits: staging-meta.json gives a component's own commit only as its version suffix ("-8253516"). A commit given
on the command line has to start with those digits. One left empty is taken from the stagings: the core's from the
modules' dependencies.opendaq.revision, a module's by looking its digits up in the module's GitHub repository. The
LT streaming commit is needed in full, because its TLS test fixtures are fetched at that commit.

The full commits are written to GITHUB_OUTPUT as <component>-revision and shown in a notice. Each problem is reported
as an error annotation, and the exit code is 1 if there is any.
"""

import argparse
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

CORE = "opendaq"
REPOSITORIES = {
    "opendaq": "openDAQ/openDAQ",
    "opcua-modules": "openDAQ/OpcUaModules",
    "lt-streaming-modules": "openDAQ/LTStreamingModulesModern",
}
SUFFIX = re.compile(r"-([0-9a-f]{7,40})")
FULL_SHA = re.compile(r"[0-9a-f]{40}")


def escape_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def describe(package):
    return f"{package.get('name')} {package.get('version')}{package.get('version.suffix', '')} ({package.get('triplet')})"


def read(folder, component, triplet):
    """(staging-meta.json, problems) of one staging; the meta is None when it cannot be read"""
    if not folder.is_dir():
        return None, [f"the artifact {folder.name} is not in this run"]

    def listed(paths):
        return ", ".join(path.relative_to(folder).as_posix() for path in paths) or "none"

    problems = []
    tarballs = sorted(folder.rglob("*.tar.gz"))
    metas = sorted(folder.rglob("staging-meta.json"))
    if len(tarballs) != 1:
        problems.append(f"{len(tarballs)} .tar.gz files instead of one: {listed(tarballs)}")
    if len(metas) != 1:
        return None, problems + [f"{len(metas)} staging-meta.json files instead of one: {listed(metas)}"]
    if len(tarballs) == 1 and tarballs[0].parent != metas[0].parent:
        problems.append(f"the tarball {listed(tarballs)} is not beside {listed(metas)}")

    try:
        meta = json.loads(metas[0].read_text(encoding="utf-8"))
        if not isinstance(meta.get("package"), dict):
            raise TypeError("no package object")
    except (OSError, ValueError, TypeError, AttributeError) as e:
        return None, problems + [f"{listed(metas)} cannot be read: {e!r}"]

    package = meta["package"]
    if package.get("name") != component:
        problems.append(f"package name is {package.get('name')!r}, not {component!r}")
    if package.get("triplet") != triplet:
        problems.append(f"triplet is {package.get('triplet')!r}, not {triplet!r} (the build job's)")
    return meta, problems


def built_against(meta):
    return ((meta.get("dependencies") or {}).get(CORE) or {}).get("revision")


def look_up(repository, short):
    """The full commit of a short one in a GitHub repository; LookupError if there is none"""
    api = os.environ.get("GITHUB_API_URL", "https://api.github.com")
    request = urllib.request.Request(f"{api}/repos/{repository}/commits/{short}",
                                     headers={"Accept": "application/vnd.github+json"})
    if os.environ.get("GITHUB_TOKEN"):
        request.add_header("Authorization", f"Bearer {os.environ['GITHUB_TOKEN']}")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            sha = json.load(response).get("sha", "")
    except (OSError, ValueError) as e:
        raise LookupError(f"commit {short} cannot be looked up in {repository}: {e}") from e
    if not FULL_SHA.fullmatch(sha) or not sha.startswith(short):
        raise LookupError(f"{repository} gives {sha!r} for commit {short}")
    return sha


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dir", required=True, type=pathlib.Path, help="folder the artifacts were downloaded to")
    parser.add_argument("--job", required=True, help="the build job, the end of the artifact names")
    parser.add_argument("--triplet", required=True, help="the build job's triplet")
    parser.add_argument("--revision", required=True, action="append", metavar="COMPONENT=[SHA]",
                        help=f"a component of the run, with its full commit or empty; one of them is {CORE}. "
                             f"Components: {', '.join(REPOSITORIES)}")
    args = parser.parse_args()

    given = {}
    for item in args.revision:
        component, _, sha = item.partition("=")
        given[component] = sha.strip()
        if component not in REPOSITORIES:
            parser.error(f"unknown component {component!r}")
        if given[component] and not FULL_SHA.fullmatch(given[component]):
            parser.error(f"{component}: {given[component]!r} is not a full 40-character commit SHA")
    if CORE not in given:
        parser.error(f"no --revision {CORE}=[SHA]")

    artifacts = {component: f"{component}-staging-{args.job}" for component in given}
    metas, problems = {}, {}
    for component, artifact in artifacts.items():
        metas[component], problems[component] = read(args.dir / artifact, component, args.triplet)
    modules = [component for component in given if component != CORE and metas[component] is not None]

    # The core: the given commit, or the one the modules were built against
    core = given[CORE]
    if not core:
        candidates = sorted({built_against(metas[module]) or "none" for module in modules})
        if len(candidates) == 1 and FULL_SHA.fullmatch(candidates[0]):
            core = candidates[0]
        else:
            problems[CORE].append("its full commit cannot be taken from the module stagings, which name the core "
                                  f"commits {', '.join(candidates) or '(no module staging)'}")
    for module in modules:
        if core and built_against(metas[module]) != core:
            problems[module].append(f"built against core {built_against(metas[module])}, not {core}")

    # Each staging's own commit: the given (or, for the core, derived) one has to start with its digits; a module's
    # that is not given is looked up
    revisions = {}
    for component, meta in metas.items():
        if meta is None or (component == CORE and not core):
            continue
        suffix = meta["package"].get("version.suffix", "")
        match = SUFFIX.fullmatch(suffix)
        if not match:
            problems[component].append(f"version suffix {suffix!r} does not name a commit")
            continue
        short = match.group(1)
        revision = core if component == CORE else given[component]
        if not revision:
            try:
                revision = look_up(REPOSITORIES[component], short)
            except LookupError as e:
                problems[component].append(str(e))
                continue
        if revision.startswith(short):
            revisions[component] = revision
        else:
            problems[component].append(f"built from {short}, not from {revision}")

    failed = False
    for component, artifact in artifacts.items():
        meta = metas[component]
        state = "FAILED" if problems[component] else f"OK, {revisions[component]}"
        print(f"{artifact}: {describe(meta['package']) if meta else '-'}: {state}", flush=True)
        for problem in problems[component]:
            print(f"::error title={escape_property(artifact)}::{escape_data(problem)}", flush=True)
        failed = failed or bool(problems[component])
    if failed:
        return 1

    summary = ", ".join(f"{component} {revision}" for component, revision in revisions.items())
    print(f"::notice title=Stagings of this run::{escape_data(summary)}", flush=True)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            for component, revision in revisions.items():
                f.write(f"{component}-revision={revision}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
