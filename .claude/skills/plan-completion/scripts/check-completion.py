#!/usr/bin/env python3
"""Pre-commit check that plans are completed correctly.

Reads only what is being committed (the index) and HEAD, never the working
tree. Usage: check-completion.py [--link-dir <dir>]...
Exit 0 when the index is in the correct state, 1 with one line per problem.
"""

from __future__ import annotations

import argparse
import os
import posixpath
import re
import subprocess
import sys
from urllib.parse import unquote

PLAN_RE = re.compile(r"\.claude/plans/(active|completed)/([^/]+\.md)")
ACTIVE = ".claude/plans/active/"
COMPLETED = ".claude/plans/completed/"
SPECS = ".claude/specs/"
BUILTIN_LINK_DIRS = (".claude/plans", ".claude/specs")
POST_MERGE = "マージ後に判定"
RESULT_VALUES = ("満たす", "満たさない", "未確認")
FENCE_RE = re.compile(r" {0,3}(`{3,}|~{3,})")
HEADING_RE = re.compile(r"(#{1,6})(?:[ \t]+(.*?))?[ \t]*$")
TOP_ITEM_RE = re.compile(r"- ")
BULLET_RE = re.compile(r"([ \t]*)- (.*)")
RECORD_RE = re.compile(r"[ \t]+- (書き写した|書き写さない):(.*)")
RESULT_RE = re.compile(r"[ \t]+- 結果:(.*)")
REASON_RE = re.compile(r"[ \t]+- 根拠:(.*)")
TARGET_RE = re.compile(r"`([^`#]+)(?:#([^`]+))?`")
INLINE_LINK_RE = re.compile(r"\[[^\]]*\]\(\s*(<[^>]*>|[^)\s]+)(?:\s+[^)]*)?\)")
REF_DEF_RE = re.compile(r" {0,3}\[[^\]]+\]:\s*(<[^>]*>|\S+)")
CODE_SPAN_RE = re.compile(r"(`+).+?\1")
SCHEME_RE = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*:")


def git(*args, check=True):
    proc = subprocess.run(
        ["git", "-c", "core.quotepath=off", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc


class Snapshot:
    """The index (what will be committed) and HEAD."""

    def __init__(self):
        self.has_head = git("rev-parse", "--verify", "-q", "HEAD", check=False).returncode == 0
        listed = git("ls-files", "-z").stdout
        self.paths = {path for path in listed.split("\0") if path}
        self.dirs = {posixpath.dirname(path) for path in self.paths}
        for path in list(self.dirs):
            while path:
                path = posixpath.dirname(path)
                self.dirs.add(path)
        self.added, self.deleted, self.modified = set(), set(), set()
        fields = git("diff", "--cached", "--no-renames", "--name-status", "-z").stdout.split("\0")
        for status, path in zip(fields[0::2], fields[1::2]):
            if status == "A":
                self.added.add(path)
            elif status == "D":
                self.deleted.add(path)
            elif path:
                self.modified.add(path)

    def head(self, path):
        if not self.has_head:
            return None
        proc = git("show", f"HEAD:{path}", check=False)
        return proc.stdout if proc.returncode == 0 else None

    def index(self, path):
        if path not in self.paths:
            return None
        return git("show", f":{path}").stdout

    def exists(self, path):
        return path in self.paths or path in self.dirs


def lines_with_fence_state(text):
    """Yield (line, inside_fence) for each line; fence delimiter lines count as inside."""
    fence = None
    for line in text.split("\n"):
        match = FENCE_RE.match(line)
        if fence is not None:
            if match and match.group(1)[0] == fence[0] and len(match.group(1)) >= len(fence):
                fence = None
            yield line, True
        elif match:
            fence = match.group(1)
            yield line, True
        else:
            yield line, False


def heading_level(line, inside_fence):
    if inside_fence:
        return None
    match = HEADING_RE.fullmatch(line)
    return len(match.group(1)) if match else None


def section(lines, title, level):
    """Return the lines under the first heading `title` of `level`, or None.

    `lines` is a list of (line, inside_fence). The section ends before the
    next heading of the same or a higher level outside fences.
    """
    heading = "#" * level + " " + title
    for start, (line, fenced) in enumerate(lines):
        if not fenced and line == heading:
            body = []
            for entry in lines[start + 1 :]:
                found = heading_level(*entry)
                if found is not None and found <= level:
                    break
                body.append(entry)
            return body
    return None


def parse(text):
    return list(lines_with_fence_state(text.replace("\r\n", "\n")))


def trim(lines):
    lines = list(lines)
    while lines and lines[-1].strip() == "":
        lines.pop()
    return lines


def top_items(lines):
    """Split section lines into items that start at a top-level "- " line."""
    items = []
    for line, fenced in lines or []:
        if not fenced and TOP_ITEM_RE.match(line):
            items.append([line])
        elif items:
            items[-1].append(line)
    return [trim(item) for item in items]


def decision_items(text):
    return top_items(section(parse(text), "Decision Log", 2))


def without_records(item):
    return [item[0]] + [line for line in item[1:] if not RECORD_RE.fullmatch(line)]


def records(item):
    return [RECORD_RE.fullmatch(line) for line in item[1:] if RECORD_RE.fullmatch(line)]


def validation_lines(text):
    found = section(parse(text), "Validation and Acceptance", 2)
    return None if found is None else trim(line for line, _ in found)


def post_merge_conditions(text):
    """Return the bodies of the bullet items that mention POST_MERGE."""
    conditions = []
    current = None
    for line, fenced in section(parse(text), "Validation and Acceptance", 2) or []:
        bullet = None if fenced else BULLET_RE.fullmatch(line)
        if bullet:
            current = [bullet.group(2), line]
            conditions.append(current)
        elif current is not None:
            current.append(line)
    return [body for body, *item_lines in conditions if any(POST_MERGE in line for line in item_lines)]


def post_merge_results(text):
    results = section(parse(text), "検証結果", 2)
    if results is None:
        return []
    return top_items(section(results, "マージ後の判定", 3))


def github_anchor(text, seen):
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    slug = re.sub(r"[^\w\- ]", "", text.strip().lower()).replace(" ", "-")
    count = seen.get(slug, 0)
    seen[slug] = count + 1
    return slug if count == 0 else f"{slug}-{count}"


def anchors(text):
    seen = {}
    found = set()
    for line, fenced in parse(text):
        if heading_level(line, fenced) is not None:
            title = HEADING_RE.fullmatch(line).group(2) or ""
            title = re.sub(r"[ \t]+#+$", "", title)
            found.add(github_anchor(title, seen))
    return found


class Checker:
    def __init__(self, snapshot, link_dirs):
        self.snap = snapshot
        self.link_dirs = tuple(d.strip("/") for d in (*BUILTIN_LINK_DIRS, *link_dirs))
        self.problems = []

    def fail(self, path, message):
        self.problems.append(f"{path}: {message}")

    def plans(self, paths, kind):
        names = set()
        for path in paths:
            match = PLAN_RE.fullmatch(path)
            if match and match.group(1) == kind:
                names.add(match.group(2))
        return names

    def run(self):
        snap = self.snap
        moved = self.plans(snap.deleted, "active") & self.plans(snap.added, "completed")
        for name in sorted(moved):
            self.check_move(name)
        for name in sorted(self.plans(snap.deleted, "active") - moved):
            self.fail(ACTIVE + name, "deleted without adding " + COMPLETED + name + " (move the plan instead)")
        for name in sorted(self.plans(snap.added | snap.modified, "active") | self.plans(snap.added | snap.modified, "completed")):
            if ACTIVE + name in snap.paths and COMPLETED + name in snap.paths:
                self.fail(ACTIVE + name, "still in active/ while " + COMPLETED + name + " exists")
        for name in sorted(self.plans(snap.modified, "active")):
            self.check_active_edit(name)
        for name in sorted(self.plans(snap.modified, "completed")):
            self.check_completed_edit(name)
        for name in sorted(self.plans(snap.deleted, "completed")):
            self.fail(COMPLETED + name, "completed plans must not be deleted")
        if moved:
            for path in sorted(p for p in snap.deleted if p.startswith(SPECS)):
                self.fail(path, "specs must not be deleted when a plan is completed")
        self.check_links()
        return self.problems

    def check_move(self, name):
        before = self.snap.head(ACTIVE + name)
        after = self.snap.index(COMPLETED + name)
        path = COMPLETED + name
        after_items = decision_items(after)
        remaining = [without_records(item) for item in after_items]
        position = 0
        for item in decision_items(before):
            while position < len(remaining) and remaining[position] != item:
                position += 1
            if position == len(remaining):
                self.fail(path, f"Decision Log item is missing or changed: {item[0]}")
                break
            position += 1
        for item in after_items:
            self.check_record(path, item)
        if validation_lines(before) != validation_lines(after):
            self.fail(path, "Validation and Acceptance must not change when the plan is moved")
        self.check_post_merge(path, post_merge_conditions(before), post_merge_results(after))

    def check_record(self, path, item):
        found = records(item)
        if len(found) != 1:
            self.fail(path, f"Decision Log item needs exactly one 書き写した/書き写さない line: {item[0]}")
            return
        kind, value = found[0].group(1), found[0].group(2).strip()
        if kind == "書き写さない":
            if not value:
                self.fail(path, f"書き写さない needs a reason: {item[0]}")
            return
        parts = [part.strip() for part in value.split("、")] if value else []
        if not parts:
            self.fail(path, f"書き写した needs a destination: {item[0]}")
        for part in parts:
            target = TARGET_RE.fullmatch(part)
            if not target:
                self.fail(path, f"書き写した destination must be `path` or `path#anchor`: {part}")
                continue
            self.check_target(path, target.group(1), target.group(2), part)

    def check_target(self, path, target, anchor, shown):
        target = posixpath.normpath(target.lstrip("/"))
        if target.startswith("../") or not self.snap.exists(target):
            self.fail(path, f"destination is not in the commit: {shown}")
        elif anchor and target.endswith(".md") and anchor not in anchors(self.snap.index(target)):
            self.fail(path, f"destination heading not found: {shown}")

    def check_post_merge(self, path, conditions, results):
        for condition in conditions:
            matches = [item for item in results if BULLET_RE.fullmatch(item[0]).group(2) == condition]
            if len(matches) != 1:
                self.fail(path, f"needs exactly one item under ### マージ後の判定 for: {condition}")
                continue
            item = matches[0]
            result = [RESULT_RE.fullmatch(line).group(1).strip() for line in item[1:] if RESULT_RE.fullmatch(line)]
            reason = [REASON_RE.fullmatch(line).group(1).strip() for line in item[1:] if REASON_RE.fullmatch(line)]
            if len(result) != 1 or result[0] not in RESULT_VALUES:
                self.fail(path, f"結果 must be one of {'/'.join(RESULT_VALUES)}: {condition}")
            if len(reason) != 1 or not reason[0]:
                self.fail(path, f"根拠 must not be empty: {condition}")

    def check_active_edit(self, name):
        path = ACTIVE + name
        before = self.snap.head(path)
        if before is not None and len(decision_items(self.snap.index(path))) < len(decision_items(before)):
            self.fail(path, "Decision Log items were removed")

    def check_completed_edit(self, name):
        path = COMPLETED + name
        before = self.snap.head(path)
        if before is None:
            return
        old, new = decision_items(before), decision_items(self.snap.index(path))
        if len(new) < len(old):
            self.fail(path, "Decision Log items were removed")
            return
        for old_item, new_item in zip(old, new):
            if records(old_item) and not records(new_item):
                self.fail(path, f"completion record was removed: {old_item[0]}")

    def in_link_scope(self, path):
        return path.endswith(".md") and any(path == d or path.startswith(d + "/") for d in self.link_dirs)

    def check_links(self):
        snap = self.snap
        for path in sorted(p for p in snap.added | snap.modified if self.in_link_scope(p)):
            for link in links(snap.index(path)):
                self.check_link(path, link)
        if not snap.deleted:
            return
        for path in sorted(p for p in snap.paths - snap.added - snap.modified if self.in_link_scope(p)):
            for link in links(snap.index(path)):
                target, _ = resolve(path, link)
                if target in snap.deleted:
                    self.check_link(path, link)

    def check_link(self, path, link):
        target, anchor = resolve(path, link)
        if target is None:
            return
        if target.startswith("../") or target == ".." or not self.snap.exists(target):
            self.fail(path, f"broken link: {link}")
        elif anchor and target.endswith(".md") and target in self.snap.paths:
            if anchor not in anchors(self.snap.index(target)):
                self.fail(path, f"broken heading link: {link}")


def links(text):
    found = []
    for line, fenced in parse(text):
        if fenced:
            continue
        definition = REF_DEF_RE.match(line)
        if definition:
            found.append(definition.group(1))
            continue
        line = CODE_SPAN_RE.sub("", line)
        found.extend(match.group(1) for match in INLINE_LINK_RE.finditer(line))
    return [link[1:-1] if link.startswith("<") and link.endswith(">") else link for link in found]


def resolve(path, link):
    """Return (target path, anchor) for a link in `path`, or (None, None) for outside links."""
    if SCHEME_RE.match(link):
        return None, None
    target, _, anchor = link.partition("#")
    target = unquote(target.split("?", 1)[0])
    anchor = unquote(anchor)
    if not target:
        return path, anchor
    if target.startswith("/"):
        joined = target.lstrip("/")
    else:
        joined = posixpath.join(posixpath.dirname(path), target)
    return posixpath.normpath(joined), anchor


def main(argv):
    parser = argparse.ArgumentParser(description="Check plan completion in the commit.")
    parser.add_argument("--link-dir", action="append", default=[], help="extra folder whose Markdown links are checked")
    args = parser.parse_args(argv)
    os.chdir(git("rev-parse", "--show-toplevel").stdout.strip())
    problems = Checker(Snapshot(), args.link_dir).run()
    if not problems:
        return 0
    for problem in problems:
        print(problem)
    print("Follow the plan-completion skill to fix the plan before committing.")
    return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
