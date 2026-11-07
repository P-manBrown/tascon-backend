"""Judge which active plans are completed, reading GitHub through `gh api` only.

Called by judge-completion.sh. See that script for the exit codes.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys

ACTIVE_DIR = ".claude/plans/active"
PER_PAGE = 100
DONE = "\u2705"
REPO_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
PLAN_LINE_RE = re.compile("- (\u2705|\U0001F3C3|\u2b1c) Plan: (\\S+)")
FENCE_RE = re.compile(r" {0,3}(`{3,}|~{3,})")
HEADING_RE = re.compile(r"#{1,3}(?:[ \t]|$)")
SECTION_TITLE = "### Related Documents"


class QueryError(Exception):
    """A GitHub query did not give a usable answer."""


def read_plan_lines(body):
    """Return (plan_refs, unreadable) from one pull request body.

    plan_refs is a list of (mark, path). unreadable is a list of the original
    lines that mention "Plan:" in the Related Documents section but are not
    plan lines, including such lines inside fenced code blocks.
    """
    refs = []
    unreadable = []
    in_section = False
    fence = None
    for line in body.replace("\r\n", "\n").split("\n"):
        if fence is not None:
            match = FENCE_RE.match(line)
            if match and match.group(1)[0] == fence[0] and len(match.group(1)) >= len(fence):
                fence = None
            if in_section and "Plan:" in line:
                unreadable.append(line)
            continue
        match = FENCE_RE.match(line)
        if match:
            fence = match.group(1)
            if in_section and "Plan:" in line:
                unreadable.append(line)
            continue
        if line == SECTION_TITLE:
            in_section = True
            continue
        if HEADING_RE.match(line):
            in_section = False
            continue
        if not in_section:
            continue
        plan_line = PLAN_LINE_RE.fullmatch(line.replace("\ufe0f", ""))
        if plan_line:
            refs.append((plan_line.group(1), plan_line.group(2)))
        elif "Plan:" in line:
            unreadable.append(line)
    return refs, unreadable


def merged_to_main(pr):
    return bool(pr["merged_at"]) and pr["base"]["ref"] == "main"


def judge(plans, prs):
    """Judge the plans (paths) against the pull requests (GitHub objects)."""
    by_number = {}
    for pr in prs:
        by_number.setdefault(pr["number"], pr)
    pointing = {}
    unreadable = []
    for number in sorted(by_number):
        refs, lines = read_plan_lines(by_number[number]["body"] or "")
        unreadable.extend({"pr": number, "line": line} for line in lines)
        for mark, path in refs:
            pointing.setdefault(path, {}).setdefault(number, set()).add(mark)
    completed = []
    missing_marker = []
    for plan in sorted(set(plans)):
        marks_by_pr = pointing.get(plan)
        if not marks_by_pr:
            continue
        if not all(merged_to_main(by_number[number]) for number in marks_by_pr):
            continue
        numbers = sorted(marks_by_pr)
        done = [number for number in numbers if DONE in marks_by_pr[number]]
        if done:
            completing = max(done, key=lambda number: (by_number[number]["merged_at"], number))
            completed.append({"plan": plan, "prs": numbers, "completing_pr": completing})
        else:
            missing_marker.append({"plan": plan, "prs": numbers})
    return {"completed": completed, "missing_marker": missing_marker, "unreadable": unreadable}


def run_gh(endpoint):
    try:
        proc = subprocess.run(
            ["gh", "api", endpoint],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
    except OSError as error:
        raise QueryError(f"cannot run gh: {error}") from error
    return proc.returncode, proc.stdout, proc.stderr


def is_not_found(stdout):
    try:
        data = json.loads(stdout)
    except ValueError:
        return False
    return isinstance(data, dict) and str(data.get("status")) == "404"


def get_json(endpoint, allow_not_found=False):
    code, stdout, stderr = run_gh(endpoint)
    if code != 0:
        if allow_not_found and is_not_found(stdout):
            return None
        raise QueryError(f"gh api {endpoint} failed with exit {code}: {stderr.strip()}")
    try:
        return json.loads(stdout)
    except ValueError as error:
        raise QueryError(f"gh api {endpoint} did not return JSON") from error


def expect(condition, endpoint):
    if not condition:
        raise QueryError(f"gh api {endpoint} returned an unexpected shape")


def fetch_main_sha(repo):
    endpoint = f"repos/{repo}/branches/main"
    data = get_json(endpoint)
    expect(isinstance(data, dict) and isinstance(data.get("commit"), dict), endpoint)
    sha = data["commit"].get("sha")
    expect(isinstance(sha, str) and sha != "", endpoint)
    return sha


def fetch_plans(repo, sha):
    endpoint = f"repos/{repo}/contents/{ACTIVE_DIR}?ref={sha}"
    data = get_json(endpoint, allow_not_found=True)
    if data is None:
        return []
    expect(isinstance(data, list), endpoint)
    plans = []
    for entry in data:
        expect(isinstance(entry, dict) and isinstance(entry.get("name"), str), endpoint)
        if entry.get("type") == "file" and entry["name"].endswith(".md"):
            plans.append(f"{ACTIVE_DIR}/{entry['name']}")
    return plans


def valid_pr(pr):
    return (
        isinstance(pr, dict)
        and isinstance(pr.get("number"), int)
        and isinstance(pr.get("body"), (str, type(None)))
        and isinstance(pr.get("merged_at"), (str, type(None)))
        and isinstance(pr.get("base"), dict)
        and isinstance(pr["base"].get("ref"), str)
    )


def fetch_prs(repo):
    prs = []
    page = 1
    while True:
        endpoint = (
            f"repos/{repo}/pulls?state=all&sort=created&direction=asc"
            f"&per_page={PER_PAGE}&page={page}"
        )
        data = get_json(endpoint)
        expect(isinstance(data, list) and all(valid_pr(pr) for pr in data), endpoint)
        prs.extend(data)
        if len(data) < PER_PAGE:
            return prs
        page += 1


def main(argv):
    if len(argv) != 2 or argv[0] != "--repo" or not REPO_RE.fullmatch(argv[1]):
        print("usage: judge-completion.sh --repo <owner>/<name>", file=sys.stderr)
        return 2
    repo = argv[1]
    try:
        sha = fetch_main_sha(repo)
        plans = fetch_plans(repo, sha)
        prs = fetch_prs(repo)
        result = judge(plans, prs)
    except QueryError as error:
        print(f"judge-completion: not verified: {error}", file=sys.stderr)
        return 3
    except Exception as error:  # noqa: BLE001 - any other failure is an internal error
        print(f"judge-completion: internal error: {error!r}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 4 if result["missing_marker"] or result["unreadable"] else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
