import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))
sys.dont_write_bytecode = True

import judge_completion  # noqa: E402

JUDGE = SCRIPTS / "judge-completion.sh"
FAKE_GH = Path(__file__).resolve().parent / "fake_gh.py"
REPO = "acme/widgets"
SHA = "0123abcd"
BRANCH = f"repos/{REPO}/branches/main"
CONTENTS = f"repos/{REPO}/contents/.claude/plans/active?ref={SHA}"
DONE = "\u2705"
RUNNING = "\U0001F3C3"
NONE = "\u2b1c"
VS16 = "\ufe0f"
PLAN_A = ".claude/plans/active/a.md"
PLAN_B = ".claude/plans/active/b.md"


def pulls(page):
    return f"repos/{REPO}/pulls?state=all&sort=created&direction=asc&per_page=100&page={page}"


def ok(data):
    return {"stdout": json.dumps(data), "stderr": "", "exit": 0}


def body(*lines, crlf=False):
    text = "\n".join(
        ["### Summary", "", "Plan: outside the section", "", "### Related Documents", "", *lines, "", "### Notes (Optional)", ""]
    )
    return text.replace("\n", "\r\n") if crlf else text


def pr(number, text, merged_at="2026-01-01T00:00:00Z", base="main"):
    return {
        "number": number,
        "state": "closed" if merged_at else "open",
        "merged_at": merged_at,
        "base": {"ref": base},
        "body": text,
    }


def closed(number, text):
    return dict(pr(number, text, merged_at=None), state="closed")


def plan_line(mark, path):
    return f"- {mark} Plan: {path}"


class ReadPlanLinesTest(unittest.TestCase):
    def test_reads_marks_with_and_without_vs16(self):
        refs, unreadable = judge_completion.read_plan_lines(
            body(plan_line(DONE + VS16, PLAN_A), plan_line(DONE, PLAN_B), plan_line(NONE + VS16, "N/A"))
        )
        self.assertEqual(refs, [(DONE, PLAN_A), (DONE, PLAN_B), (NONE, "N/A")])
        self.assertEqual(unreadable, [])

    def test_returns_lines_that_are_not_plan_lines(self):
        lines = [
            f"- {DONE}\u3000Plan: {PLAN_A}",
            f"- {RUNNING} Plan: {PLAN_A} ",
            f"-  {DONE} Plan: {PLAN_A}",
            "Plan: somewhere",
        ]
        refs, unreadable = judge_completion.read_plan_lines(body(*lines))
        self.assertEqual(refs, [])
        self.assertEqual(unreadable, lines)

    def test_ignores_lines_outside_the_section(self):
        text = f"{plan_line(DONE, PLAN_A)}\n### Summary\n{plan_line(DONE, PLAN_A)}\n"
        self.assertEqual(judge_completion.read_plan_lines(text), ([], []))

    def test_fenced_lines_are_unreadable(self):
        fenced = plan_line(DONE, PLAN_A)
        refs, unreadable = judge_completion.read_plan_lines(body("```", fenced, "```", "~~~md", fenced, "~~~"))
        self.assertEqual(refs, [])
        self.assertEqual(unreadable, [fenced, fenced])

    def test_heading_inside_fence_does_not_end_the_section(self):
        refs, _ = judge_completion.read_plan_lines(body("```", "## not a heading", "```", plan_line(DONE, PLAN_A)))
        self.assertEqual(refs, [(DONE, PLAN_A)])

    def test_level_four_heading_keeps_the_section(self):
        refs, _ = judge_completion.read_plan_lines(body("#### Detail", plan_line(DONE, PLAN_A)))
        self.assertEqual(refs, [(DONE, PLAN_A)])

    def test_level_two_heading_ends_the_section(self):
        refs, unreadable = judge_completion.read_plan_lines(body("## Next", plan_line(DONE, PLAN_A)))
        self.assertEqual((refs, unreadable), ([], []))

    def test_crlf_is_a_line_break(self):
        refs, unreadable = judge_completion.read_plan_lines(body(plan_line(DONE, PLAN_A), crlf=True))
        self.assertEqual((refs, unreadable), ([(DONE, PLAN_A)], []))

    def test_unreadable_keeps_the_original_line(self):
        line = f"- {DONE}{VS16} Plan:{PLAN_A}"
        self.assertEqual(judge_completion.read_plan_lines(body(line)), ([], [line]))


class JudgeCommandTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.bin = root / "bin"
        self.bin.mkdir()
        self.workdir = root / "empty"
        self.workdir.mkdir()
        self.config = root / "config.json"
        self.log = root / "calls.jsonl"
        gh = self.bin / "gh"
        gh.write_text(f'#!/bin/sh\nexec "{sys.executable}" -B "{FAKE_GH}" "$@"\n', encoding="utf-8")
        gh.chmod(0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def respond(self, plans=("a.md",), prs=(), **overrides):
        responses = {
            BRANCH: ok({"name": "main", "commit": {"sha": SHA}}),
            CONTENTS: ok(
                [{"type": "file", "name": ".gitkeep"}, {"type": "dir", "name": "notes.md"}]
                + [{"type": "file", "name": name} for name in plans]
            ),
        }
        prs = list(prs)
        page = 1
        while True:
            chunk = prs[(page - 1) * 100 : page * 100]
            responses[pulls(page)] = ok(chunk)
            if len(chunk) < 100:
                break
            page += 1
        responses.update(overrides)
        self.config.write_text(json.dumps(responses), encoding="utf-8")

    def run_judge(self, *args):
        env = dict(os.environ, PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}")
        env["FAKE_GH_CONFIG"] = str(self.config)
        env["FAKE_GH_LOG"] = str(self.log)
        proc = subprocess.run(
            ["bash", str(JUDGE), *args],
            cwd=self.workdir,
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )
        return proc.returncode, proc.stdout, proc.stderr

    def judge(self):
        return self.run_judge("--repo", REPO)

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]

    def assert_result(self, expected_code, completed=(), missing_marker=(), unreadable=()):
        code, out, err = self.judge()
        self.assertEqual(code, expected_code, err)
        self.assertEqual(
            json.loads(out),
            {"completed": list(completed), "missing_marker": list(missing_marker), "unreadable": list(unreadable)},
        )
        self.assertEqual(out.count("\n"), 1)

    def assert_not_verified(self):
        code, out, err = self.judge()
        self.assertEqual(code, 3, err)
        self.assertEqual(out, "")
        self.assertNotEqual(err.strip(), "")

    def test_no_pull_requests(self):
        self.respond(prs=[])
        self.assert_result(0)

    def test_all_merged_with_done_mark(self):
        self.respond(
            prs=[
                pr(10, body(plan_line(RUNNING, PLAN_A)), merged_at="2026-01-01T00:00:00Z"),
                pr(12, body(plan_line(DONE, PLAN_A)), merged_at="2026-01-03T00:00:00Z"),
            ]
        )
        self.assert_result(0, completed=[{"plan": PLAN_A, "prs": [10, 12], "completing_pr": 12}])

    def test_completing_pr_is_the_last_merged_done_pr(self):
        self.respond(
            prs=[
                pr(10, body(plan_line(DONE, PLAN_A)), merged_at="2026-01-05T00:00:00Z"),
                pr(12, body(plan_line(DONE, PLAN_A)), merged_at="2026-01-03T00:00:00Z"),
            ]
        )
        self.assert_result(0, completed=[{"plan": PLAN_A, "prs": [10, 12], "completing_pr": 10}])

    def test_done_and_running_in_one_pr_counts_as_done(self):
        self.respond(prs=[pr(10, body(plan_line(RUNNING, PLAN_A), plan_line(DONE, PLAN_A)))])
        self.assert_result(0, completed=[{"plan": PLAN_A, "prs": [10], "completing_pr": 10}])

    def test_open_pull_request_blocks_completion(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, PLAN_A))), pr(13, body(plan_line(RUNNING, PLAN_A)), merged_at=None)])
        self.assert_result(0)

    def test_closed_pull_request_blocks_completion(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, PLAN_A))), closed(11, body(plan_line(RUNNING, PLAN_A)))])
        self.assert_result(0)

    def test_merge_into_another_branch_blocks_completion(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, PLAN_A)), base="feature")])
        self.assert_result(0)

    def test_missing_done_mark(self):
        self.respond(prs=[pr(10, body(plan_line(RUNNING, PLAN_A))), pr(12, body(plan_line(RUNNING, PLAN_A)))])
        self.assert_result(4, missing_marker=[{"plan": PLAN_A, "prs": [10, 12]}])

    def test_plan_not_on_main_is_not_judged(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, ".claude/plans/active/other.md")))])
        self.assert_result(0)

    def test_completed_path_does_not_match_the_active_plan(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, ".claude/plans/completed/a.md")))])
        self.assert_result(0)

    def test_unreadable_lines(self):
        fullwidth = f"- {DONE}\u3000Plan: {PLAN_A}"
        trailing = f"- {RUNNING} Plan: {PLAN_A} "
        fenced = plan_line(DONE, PLAN_A)
        self.respond(
            prs=[
                pr(11, body(fullwidth, trailing, plan_line(NONE + VS16, "N/A"))),
                pr(10, body("```", fenced, "```")),
            ]
        )
        self.assert_result(
            4,
            unreadable=[
                {"pr": 10, "line": fenced},
                {"pr": 11, "line": fullwidth},
                {"pr": 11, "line": trailing},
            ],
        )

    def test_vs16_marks_complete_a_plan(self):
        self.respond(prs=[pr(10, body(plan_line(DONE + VS16, PLAN_A)))])
        self.assert_result(0, completed=[{"plan": PLAN_A, "prs": [10], "completing_pr": 10}])

    def test_fenced_done_line_does_not_complete(self):
        self.respond(prs=[pr(10, body("```", plan_line(DONE, PLAN_A), "```"))])
        self.assert_result(4, unreadable=[{"pr": 10, "line": plan_line(DONE, PLAN_A)}])

    def test_crlf_body(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, PLAN_A), crlf=True))])
        self.assert_result(0, completed=[{"plan": PLAN_A, "prs": [10], "completing_pr": 10}])

    def test_output_order(self):
        self.respond(
            plans=("b.md", "a.md"),
            prs=[
                pr(20, body(plan_line(DONE, PLAN_B))),
                pr(10, body(plan_line(DONE, PLAN_A))),
            ],
        )
        self.assert_result(
            0,
            completed=[
                {"plan": PLAN_A, "prs": [10], "completing_pr": 10},
                {"plan": PLAN_B, "prs": [20], "completing_pr": 20},
            ],
        )

    def test_reads_every_page(self):
        prs = [pr(n, body(plan_line(RUNNING, PLAN_A))) for n in range(1, 150)]
        prs.append(pr(150, body(plan_line(DONE, PLAN_A)), merged_at="2026-02-01T00:00:00Z"))
        self.respond(prs=prs)
        self.assert_result(0, completed=[{"plan": PLAN_A, "prs": list(range(1, 151)), "completing_pr": 150}])
        self.assertEqual(
            [call[1] for call in self.calls()],
            [BRANCH, CONTENTS, pulls(1), pulls(2)],
        )

    def test_exactly_one_full_page_reads_the_empty_next_page(self):
        self.respond(prs=[pr(n, body()) for n in range(1, 101)])
        self.assert_result(0)
        self.assertEqual(self.calls()[-1][1], pulls(2))

    def test_failed_later_page_is_not_verified(self):
        prs = [pr(n, body(plan_line(DONE, PLAN_A))) for n in range(1, 101)]
        self.respond(prs=prs, **{pulls(2): {"stdout": "", "stderr": "HTTP 502", "exit": 1}})
        self.assert_not_verified()

    def test_branch_failure_is_not_verified(self):
        self.respond(**{BRANCH: {"stdout": "", "stderr": "gh: auth required", "exit": 4}})
        self.assert_not_verified()

    def test_contents_failure_is_not_verified(self):
        self.respond(**{CONTENTS: {"stdout": '{"message":"Server Error","status":"500"}', "stderr": "", "exit": 1}})
        self.assert_not_verified()

    def test_missing_active_folder_means_no_plans(self):
        self.respond(
            prs=[pr(10, body(plan_line(DONE, PLAN_A)))],
            **{
                CONTENTS: {
                    "stdout": '{"message":"Not Found","status":"404"}',
                    "stderr": "gh: Not Found (HTTP 404)\n",
                    "exit": 1,
                }
            },
        )
        self.assert_result(0)

    def test_not_found_on_branch_is_not_verified(self):
        self.respond(**{BRANCH: {"stdout": '{"message":"Not Found","status":"404"}', "stderr": "", "exit": 1}})
        self.assert_not_verified()

    def test_non_json_response_is_not_verified(self):
        self.respond(**{pulls(1): {"stdout": "<html>", "stderr": "", "exit": 0}})
        self.assert_not_verified()

    def test_unexpected_shape_is_not_verified(self):
        self.respond(**{pulls(1): ok({"message": "not a list"})})
        self.assert_not_verified()

    def test_missing_gh_is_not_verified(self):
        empty_path = Path(self.tmp.name) / "no-gh"
        empty_path.mkdir()
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, {"PATH": str(empty_path)}), redirect_stdout(out), redirect_stderr(err):
            code = judge_completion.main(["--repo", REPO])
        self.assertEqual(code, 3)
        self.assertEqual(out.getvalue(), "")
        self.assertIn("gh", err.getvalue())

    def test_usage_errors(self):
        self.respond()
        for args in ([], ["--repo"], ["--repo", "widgets"], ["--repo", REPO, "extra"], ["--owner", REPO]):
            with self.subTest(args=args):
                code, out, err = self.run_judge(*args)
                self.assertEqual(code, 2)
                self.assertEqual(out, "")
                self.assertIn("usage", err)
        self.assertEqual(self.calls(), [])

    def test_only_reads_and_writes_nothing(self):
        self.respond(prs=[pr(10, body(plan_line(DONE, PLAN_A)))])
        self.judge()
        self.assertEqual(list(self.workdir.iterdir()), [])
        for call in self.calls():
            self.assertEqual(len(call), 2)
            self.assertEqual(call[0], "api")


if __name__ == "__main__":
    unittest.main()
