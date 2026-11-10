"""Reports the test results of one platform as annotations.

- one notice with the counts of passed, failed, disabled and skipped tests;
- one error per test app that ctest reports as failed without a failed test in its gtest XML (a crash, an abort or
  a timeout), naming the test that was running;
- one error per failed test, linked to the failing line when it is in this repository.

Reads the gtest XML files (GTEST_OUTPUT=xml:<folder>/) and the ctest JUnit file (written as the test preset ci-tests
sets: output truncated at its head, so that a failed test app keeps the end of its output). The files may come from
another machine: failure locations are matched to this repository's files by the end of their paths. GitHub shows at
most 10 error annotations per step, so the errors past the ninth are counted in the last one; all of them are printed
to the log.
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

MAX_ERRORS = 10
MAX_MESSAGE_LINES = 30

RUN = re.compile(r"^\[ RUN      \] (\S+)", re.MULTILINE)
RESULT = re.compile(r"^\[ +(?:OK|FAILED|SKIPPED) +\] (\S+)", re.MULTILINE)


def escape_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def annotate(level, title, message, file=None, line=None):
    properties = ([f"file={escape_property(file)}"] if file else []) + ([f"line={line}"] if file and line else [])
    properties.append(f"title={escape_property(title)}")
    print(f"::{level} {','.join(properties)}::{escape_data(message)}", flush=True)


def tracked_files(source_root):
    """{lower-case path: path} of the files of this repository"""
    try:
        output = subprocess.run(["git", "-C", source_root, "ls-files"], check=True, capture_output=True, text=True)
    except (OSError, subprocess.CalledProcessError):
        return {}
    return {path.lower(): path for path in output.stdout.splitlines()}


def repo_location(path, line, tracked):
    """(path relative to the repository, line) when the path is a file of this repository, else (None, None)

    The path is the build machine's, and its checkout folder differs per platform (D:\\a\\..., /__w/... in containers,
    /Users/runner/...), so the longest end of the path that is a file of this repository is taken. A path in the
    build folder, which holds the fetched sources and dependencies, is not a file of this repository.
    """
    if not path:
        return None, None
    parts = path.replace("\\", "/").split("/")
    for start in range(len(parts)):
        file = tracked.get("/".join(parts[start:]).lower())
        if file:
            in_build_folder = any(part.lower() == "build" for part in parts[:start])
            return (None, None) if in_build_folder else (file, line)
    return None, None


def outcome(case):
    if case.find("failure") is not None:
        return "failed"
    if case.get("status") == "notrun" or case.get("result") == "suppressed":
        return "disabled"
    if case.get("result") == "skipped" or case.find("skipped") is not None:
        return "skipped"
    return "passed"


def failure_location(case, text):
    """File and line of the first failure; the test's own definition when gtest reports an unknown file"""
    first_line = text.split("\n", 1)[0]
    path, _, line = first_line.rpartition(":")
    if path and line.isdigit():
        return path, line
    return case.get("file"), case.get("line")


def last_running_test(output):
    """Name of the last test that started without a result, or None"""
    results = {match.group(1): match.end() for match in RESULT.finditer(output)}
    started = list(RUN.finditer(output))
    if started and results.get(started[-1].group(1), -1) < started[-1].end():
        return started[-1].group(1)
    return None


def trimmed(text):
    lines = text.strip().splitlines()
    if len(lines) <= MAX_MESSAGE_LINES:
        return "\n".join(lines)
    return "\n".join(lines[:MAX_MESSAGE_LINES] + [f"... {len(lines) - MAX_MESSAGE_LINES} more lines in the log"])


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--platform", required=True, help="name in the annotations, e.g. Windows")
    parser.add_argument("--gtest-xml-dir", type=pathlib.Path, required=True)
    parser.add_argument("--ctest-junit", type=pathlib.Path, required=True)
    parser.add_argument("--source-root", default=os.environ.get("GITHUB_WORKSPACE", os.getcwd()),
                        help="checkout of this repository, for the list of its files")
    args = parser.parse_args()

    tracked = tracked_files(args.source_root)
    counts = dict.fromkeys(("passed", "failed", "disabled", "skipped"), 0)
    apps_with_failures, errors = set(), []

    xml_files = sorted(args.gtest_xml_dir.glob("*.xml")) if args.gtest_xml_dir.is_dir() else []
    for xml_file in xml_files:
        for case in ET.parse(xml_file).getroot().iter("testcase"):
            result = outcome(case)
            counts[result] += 1
            if result != "failed":
                continue
            apps_with_failures.add(xml_file.stem)
            text = "\n\n".join((failure.text or failure.get("message", "")).strip() for failure in case.iter("failure"))
            file, line = repo_location(*failure_location(case, text), tracked)
            name = f"{case.get('classname')}.{case.get('name')}"
            errors.append((f"{args.platform}: {name} failed", trimmed(text), file, line))

    apps_without_results = []
    if args.ctest_junit.is_file():
        for case in ET.parse(args.ctest_junit).getroot().iter("testcase"):
            app = case.get("name")
            if case.get("status") != "fail" or app in apps_with_failures:
                continue
            failure = case.find("failure")
            reason = failure.get("message") if failure is not None and failure.get("message") else "Failed"
            running = last_running_test(case.findtext("system-out") or "")
            if running:
                message = f"{app} ended with {reason} while running {running}; tests that had not finished have no results."
            else:
                message = f"{app} ended with {reason} although none of its tests failed (exit code, test setup or teardown)."
            apps_without_results.append(app)
            errors.insert(len(apps_without_results) - 1, (f"{args.platform}: {app} ended with {reason}", message, None, None))

    if not xml_files and not args.ctest_junit.is_file():
        annotate("notice", f"{args.platform}: no test results", "No test ran: the configure, build or test step failed before any test ended.")
        return 0

    summary = f"{sum(counts.values())} tests: " + ", ".join(f"{count} {name}" for name, count in counts.items())
    if apps_without_results:
        summary += f"; ended without results for all their tests: {', '.join(apps_without_results)}"
    annotate("notice", f"{args.platform}: test results", summary)

    if errors:
        print(f"{args.platform}: all failures")
        for title, _, _, _ in errors:
            print(f"  {title}")
    if len(errors) > MAX_ERRORS:
        rest = errors[MAX_ERRORS - 1:]
        errors = errors[:MAX_ERRORS - 1] + [(f"{args.platform}: {len(rest)} more failures",
                                              "\n".join(title for title, _, _, _ in rest), None, None)]
    for title, message, file, line in errors:
        annotate("error", title, message, file, line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
