# rule-testerのガードが移す前の計画の置き場所（.claude/plans）も禁止している
- **Status:** Open
- **Priority:** Low
- **Category:** Code
- **Area:** `.claude/hooks/rule-tester-guard.sh`, `.claude/hooks/tests/test-rule-tester-guard.sh`
- **Detected:** 2026-11-21
- **Description:** 計画の置き場所は`.claude/plans/`から`docs/design/plans/`へ移った。ルール・skillの比較テスト（`.claude/rules/claude-md-maintenance.md`）は、変更前のコミットへ移り、そこへ今の`rule-tester`のガードを置いて変更前の挙動を見る。移る先のコミットが移動より前だと計画はまだ`.claude/plans/`にあるため、ガードは`docs/design/plans/`に加えて`.claude/plans/`も読み取りを禁止し、ダミーの`rule-test-fixture.md`も両方の場所で許可している。`tests/test-rule-tester-guard.sh`にも`.claude/plans/`の試しがある。
- **Impact:** 移動より前から始めたブランチの変更を比較テストする間は必要な禁止である。そうしたブランチがなくなった後も残すと、もう存在しない場所の禁止と試しがガードに残り、読む人が今も`.claude/plans/`を使うのかと迷う。
- **Proposed Resolution:** 移動より前から始めた変更（計画の置き場所を移したPRより前にできたブランチ）がすべてマージまたは破棄され、比較テストで移動より前のコミットへ移ることがなくなった時点で、ガードの禁止の一覧と`rule-test-fixture.md`の許可から`.claude/plans`を外し、理由の文からも消す。あわせて`tests/test-rule-tester-guard.sh`の`.claude/plans`の試しを外す。
- **Related:** [PR #806](https://github.com/P-manBrown/tascon-backend/pull/806)
