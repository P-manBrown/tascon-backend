import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECK = Path(__file__).resolve().parent.parent / "check-completion.py"
ACTIVE_A = ".claude/plans/active/a.md"
COMPLETED_A = ".claude/plans/completed/a.md"
NOTE = "docs/notes/x.md"
POST = "マージ後に判定: the next completion uses the tool"
DECISIONS = [
    "- 2026-01-01: keep the tool small",
    "- 2026-01-02: read the index\n  because the working tree can differ",
]
VALIDATION = ["- the tool works", "  - with nested detail", f"- {POST}"]
RECORDS = [f"  - 書き写した: `{NOTE}`", "  - 書き写さない: only matters to this plan"]
RESULTS = ["### マージ後の判定", "", f"- {POST}", "  - 結果: 満たす", "  - 根拠: ran it on main and saw it stop"]
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "test",
    "GIT_AUTHOR_EMAIL": "test@example.com",
    "GIT_COMMITTER_NAME": "test",
    "GIT_COMMITTER_EMAIL": "test@example.com",
}


def plan(decisions=DECISIONS, validation=VALIDATION, results=(), context="Build the tool."):
    lines = ["# Plan A", "", "## Context/Purpose", "", context, "", "## Progress", "", "- [x] Step1: build it", ""]
    lines += ["## 検証結果", "", "- Step1: tests pass", "", *results, ""]
    if decisions is not None:
        lines += ["## Decision Log", "", *decisions, ""]
    if validation is not None:
        lines += ["## Validation and Acceptance", "", *validation, ""]
    return "\n".join(lines)


def recorded(decisions=DECISIONS, records=RECORDS):
    return [f"{item}\n{record}" if record else item for item, record in zip(decisions, records)]


def completed(decisions=None, results=RESULTS, **kwargs):
    return plan(decisions=recorded() if decisions is None else decisions, results=results, **kwargs)


class Repo:
    def __init__(self, root):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.git("init", "-q", "-b", "main")

    def git(self, *args):
        env = dict(os.environ, **GIT_ENV)
        proc = subprocess.run(["git", *args], cwd=self.root, env=env, capture_output=True, text=True, check=False)
        if proc.returncode != 0:
            raise AssertionError(f"git {args} failed: {proc.stderr}")
        return proc.stdout

    def write(self, path, text, stage=True):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text, encoding="utf-8")
        if stage:
            self.git("add", "--", path)

    def remove(self, path):
        self.git("rm", "-q", "--", path)

    def commit(self):
        self.git("commit", "-q", "--no-verify", "-m", "commit")

    def check(self, *args):
        env = dict(os.environ, **GIT_ENV)
        proc = subprocess.run(
            [sys.executable, "-B", str(CHECK), *args],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )
        return proc.returncode, proc.stdout + proc.stderr


class CheckCompletionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Repo(self.tmp.name)
        self.repo.write(ACTIVE_A, plan())
        self.repo.write(NOTE, "# X\n\n## 決めたこと\n\n## 決めたこと\n")
        self.repo.write("src/app.py", "print('a')\n")
        self.repo.commit()

    def tearDown(self):
        self.tmp.cleanup()

    def move(self, text):
        self.repo.remove(ACTIVE_A)
        self.repo.write(COMPLETED_A, text)

    def assert_passes(self, *args):
        code, out = self.repo.check(*args)
        self.assertEqual(code, 0, out)

    def assert_stops(self, expected, *args):
        code, out = self.repo.check(*args)
        self.assertEqual(code, 1, out)
        self.assertIn(expected, out)
        self.assertIn("plan-completion", out)

    # moves

    def test_correct_move_seen_as_rename(self):
        self.move(completed())
        self.assertIn("R", self.repo.git("diff", "--cached", "-M", "--name-status"))
        self.assert_passes()

    def test_correct_move_seen_as_add_and_delete(self):
        self.repo.write(ACTIVE_A, plan(context="\n".join(f"old context line {n}" for n in range(80))))
        self.repo.commit()
        self.move(completed(context="Done."))
        status = self.repo.git("diff", "--cached", "-M", "--name-status")
        self.assertIn(f"D\t{ACTIVE_A}", status)
        self.assertIn(f"A\t{COMPLETED_A}", status)
        self.assert_passes()

    def test_missing_decision_item(self):
        self.move(completed(decisions=recorded()[:1]))
        self.assert_stops("Decision Log item is missing or changed")

    def test_changed_decision_item(self):
        items = recorded()
        items[0] = items[0].replace("small", "tiny")
        self.move(completed(decisions=items))
        self.assert_stops("Decision Log item is missing or changed")

    def test_missing_record(self):
        self.move(completed(decisions=recorded(records=[RECORDS[0], None])))
        self.assert_stops("needs exactly one")

    def test_two_records(self):
        self.move(completed(decisions=recorded(records=[RECORDS[0], RECORDS[1] + "\n" + RECORDS[0]])))
        self.assert_stops("needs exactly one")

    def test_destination_missing(self):
        self.move(completed(decisions=recorded(records=["  - 書き写した: `docs/notes/none.md`", RECORDS[1]])))
        self.assert_stops("destination is not in the commit")

    def test_destination_must_be_quoted(self):
        self.move(completed(decisions=recorded(records=[f"  - 書き写した: {NOTE}", RECORDS[1]])))
        self.assert_stops("must be `path` or `path#anchor`")

    def test_destination_anchor(self):
        for anchor, ok in (("決めたこと", True), ("決めたこと-1", True), ("無い見出し", False)):
            with self.subTest(anchor=anchor):
                record = f"  - 書き写した: `{NOTE}#{anchor}`、`src/app.py`"
                self.move(completed(decisions=recorded(records=[record, RECORDS[1]])))
                if ok:
                    self.assert_passes()
                else:
                    self.assert_stops("destination heading not found")
                self.repo.git("reset", "-q", "--hard")

    def test_destination_added_in_the_same_commit(self):
        self.repo.write("docs/notes/new.md", "# New\n")
        self.move(completed(decisions=recorded(records=["  - 書き写した: `docs/notes/new.md`", RECORDS[1]])))
        self.assert_passes()

    def test_empty_reason(self):
        self.move(completed(decisions=recorded(records=[RECORDS[0], "  - 書き写さない: "])))
        self.assert_stops("書き写さない needs a reason")

    def test_missing_result(self):
        self.move(completed(results=RESULTS[:3] + RESULTS[4:]))
        self.assert_stops("結果 must be one of")

    def test_unknown_result(self):
        self.move(completed(results=RESULTS[:3] + ["  - 結果: たぶん"] + RESULTS[4:]))
        self.assert_stops("結果 must be one of")

    def test_missing_reason(self):
        self.move(completed(results=RESULTS[:4]))
        self.assert_stops("根拠 must not be empty")

    def test_empty_reason_for_result(self):
        self.move(completed(results=RESULTS[:4] + ["  - 根拠: "]))
        self.assert_stops("根拠 must not be empty")

    def test_missing_post_merge_item(self):
        self.move(completed(results=()))
        self.assert_stops("needs exactly one item under ### マージ後の判定")

    def test_unverified_with_reason_passes(self):
        self.move(completed(results=RESULTS[:3] + ["  - 結果: 未確認", "  - 根拠: no pull request on main uses it yet"]))
        self.assert_passes()

    def test_changed_validation(self):
        self.move(completed(validation=VALIDATION + ["- one more"]))
        self.assert_stops("Validation and Acceptance must not change")

    def test_plan_without_sections(self):
        self.repo.write(ACTIVE_A, plan(decisions=None, validation=None))
        self.repo.commit()
        self.move(plan(decisions=None, validation=None))
        self.assert_passes()

    def test_staged_content_is_checked_not_the_working_tree(self):
        self.move(completed(decisions=recorded(records=[RECORDS[0], None])))
        self.repo.write(COMPLETED_A, completed(), stage=False)
        self.assert_stops("needs exactly one")

    # other plan changes

    def test_delete_only(self):
        self.repo.remove(ACTIVE_A)
        self.assert_stops("deleted without adding")

    def test_rename_inside_active(self):
        self.repo.remove(ACTIVE_A)
        self.repo.write(".claude/plans/active/b.md", plan())
        self.assert_stops("deleted without adding")

    def test_active_left_behind(self):
        self.repo.write(COMPLETED_A, completed())
        self.assert_stops("still in active/")

    def test_removing_a_decision_item_from_an_active_plan(self):
        self.repo.write(ACTIVE_A, plan(decisions=DECISIONS[:1]))
        self.assert_stops("Decision Log items were removed")

    def test_fixing_text_in_an_active_plan(self):
        self.repo.write(ACTIVE_A, plan(decisions=[DECISIONS[0].replace("small", "tiny"), DECISIONS[1]]))
        self.assert_passes()

    def test_fenced_lines_are_not_decision_items(self):
        self.repo.write(ACTIVE_A, plan(decisions=[DECISIONS[0] + "\n```\n- not an item\n```", DECISIONS[1]]))
        self.repo.commit()
        self.repo.write(ACTIVE_A, plan())
        self.assert_passes()

    def test_fixing_text_in_an_old_completed_plan(self):
        self.repo.write(".claude/plans/completed/old.md", plan())
        self.repo.commit()
        self.repo.write(".claude/plans/completed/old.md", plan(decisions=[DECISIONS[0].replace("small", "tiny"), DECISIONS[1]]))
        self.assert_passes()

    def test_removing_a_record_from_a_completed_plan(self):
        self.move(completed())
        self.repo.commit()
        self.repo.write(COMPLETED_A, completed(decisions=recorded(records=[RECORDS[0], None])))
        self.assert_stops("completion record was removed")

    def test_removing_an_item_from_a_completed_plan(self):
        self.move(completed())
        self.repo.commit()
        self.repo.write(COMPLETED_A, completed(decisions=recorded()[:1]))
        self.assert_stops("Decision Log items were removed")

    def test_deleting_a_completed_plan(self):
        self.move(completed())
        self.repo.commit()
        self.repo.remove(COMPLETED_A)
        self.assert_stops("completed plans must not be deleted")

    def test_deleting_a_spec_with_a_move(self):
        self.repo.write(".claude/specs/a.md", "# Spec\n")
        self.repo.commit()
        self.move(completed())
        self.repo.remove(".claude/specs/a.md")
        self.assert_stops("specs must not be deleted")

    def test_deleting_a_spec_without_a_move(self):
        self.repo.write(".claude/specs/a.md", "# Spec\n")
        self.repo.commit()
        self.repo.remove(".claude/specs/a.md")
        self.assert_passes()

    # links

    def test_link_into_the_moved_plan(self):
        self.move(completed())
        self.repo.write("docs/notes/y.md", "# Y\n\n[plan](../../.claude/plans/completed/a.md#decision-log)\n")
        self.assert_passes("--link-dir", "docs/notes")

    def test_broken_link_in_a_link_dir(self):
        self.repo.write("docs/notes/y.md", "# Y\n\n[gone](missing.md)\n")
        self.assert_stops("broken link: missing.md", "--link-dir", "docs/notes")

    def test_link_dirs_not_passed_are_not_checked(self):
        self.repo.write("docs/notes/y.md", "# Y\n\n[gone](missing.md)\n")
        self.repo.write("README.md", "[gone](missing.md)\n")
        self.assert_passes()

    def test_broken_heading_link(self):
        self.repo.write("docs/notes/y.md", "# Y\n\n[x](x.md#無い見出し)\n[x][ref]\n\n[ref]: x.md#決めたこと-1\n")
        self.assert_stops("broken heading link: x.md#無い見出し", "--link-dir", "docs/notes")

    def test_link_to_a_file_deleted_in_this_commit(self):
        self.repo.write("docs/notes/y.md", "# Y\n\n[plan](../../.claude/plans/active/a.md)\n")
        self.repo.commit()
        self.move(completed())
        self.assert_stops("broken link: ../../.claude/plans/active/a.md", "--link-dir", "docs/notes")

    def test_plan_links_are_checked_without_link_dirs(self):
        self.repo.write(ACTIVE_A, plan(context="See [the spec](../../specs/none.md)."))
        self.assert_stops("broken link: ../../specs/none.md")

    def test_outside_links_code_and_encoded_paths(self):
        text = "\n".join(
            [
                "# Y",
                "[out](https://example.com/#x) [mail](mailto:a@example.com)",
                "`[code](missing.md)`",
                "```",
                "[fenced](missing.md)",
                "```",
                "[encoded](%E6%97%A5%E6%9C%AC.md)",
                "",
            ]
        )
        self.repo.write("docs/notes/日本.md", "# 日本\n")
        self.repo.write("docs/notes/y.md", text)
        self.assert_passes("--link-dir", "docs/notes")

    # unrelated commits

    def test_unrelated_commit(self):
        self.repo.write("src/app.py", "print('b')\n")
        self.assert_passes("--link-dir", "docs/notes")

    def test_first_commit(self):
        repo = Repo(Path(self.tmp.name) / "fresh")
        repo.write(ACTIVE_A, plan())
        repo.write(COMPLETED_A.replace("a.md", "b.md"), completed())
        code, out = repo.check()
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main()
