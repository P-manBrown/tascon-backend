# ルール・hook変更時のテストの対象範囲

## Context/Purpose

`claude-md-maintenance`ルールの比較テスト（`rule-tester`で変更前後の挙動を比べる手順）は、見出しと本文が「ルールを追加・変更したら」となっていて、skill・`CLAUDE.md`が対象か読み取りにくい。ルートの`AGENTS.md`はルールの`paths`に入っておらず、変更しても手順が読み込まれない。

hookについては、`hooks-authoring`ルールに設計上の注意しかなく、変更後に何を確かめるかが書かれていない。hookは入力に対して決まった出力を返すため、`rule-tester`の比較テストではなく、スクリプトを実際に実行するテストで確かめる。

## 合意した方針

- `claude-md-maintenance`ルールの`paths`に`AGENTS.md`を足し、手順の見出しと本文の対象を`CLAUDE.md`・`AGENTS.md`・rules・skillと明示する
- `hooks-authoring`ルールに、hookを変更したときの確認（入力JSONをstdinへ与えた直接実行、発火すべきでない入力で何も出ないこと、`settings.json`へ登録した実セッションで発火すること）を足す
- 2つの変更は別のブランチに分ける

## Branches

- docs/rule-test-scope（Step1）
- docs/hook-change-tests（Step2）

## Progress

- [x] Step1: `claude-md-maintenance`ルールの`paths`に`AGENTS.md`を足し、比較テストの手順の見出しと本文の対象を`CLAUDE.md`・`AGENTS.md`・rules・skillと明示する。比較テストを行う
  - 比較テストで行動が変わらず、変更を取り消した（結果は検証結果）
  - ユーザーの指示で、見出しを対象のファイル・フォルダを列記した名前にし、本文に対象を列記して変更し直した。手順を匂わせない質問で再テストし、行動は変わらなかったが、人が読んで対象が分かるよう変更を残す（Decision Log）
- [x] Step2: `hooks-authoring`ルールに、hookを変更したときの確認を足す。比較テストを行う
  - Step1のコミット（`6ae6215a`）の後、`docs/rule-test-scope`の上に`docs/hook-change-tests`を挿入して作業する

## 検証結果

- Step1の比較テスト（2026-10-22）: 他の変更を退避し、「ルートの`AGENTS.md`に『コントローラーのアクションは7つ以内にする』という1行を追加した。コミット前に何をする必要があるか」を問うと、変更前も変更後も、`claude-md-maintenance`の比較テストの手順を`AGENTS.md`を対象に行うと答えた（どちらも置き場所を`controllers.md`へ移す検討を先に挙げた）。行動が変わらなかったため、変更を取り消した。どちらの`rule-tester`も`claude-md-maintenance.md`を自分で読んで答えており、`paths`への`AGENTS.md`の追加（`AGENTS.md`を読んだときにルールが読み込まれるか）は、このプロンプトでは確かめられていない
- Step1の再テスト（2026-10-22）: 見出しを「CLAUDE.md・AGENTS.md・rules・skillsの作成・変更時の必須手順」にし対象を列記した変更で、「ルートの`AGENTS.md`の『1. 実装前に考える』の文言を少し直した。コミットメッセージ案を出して」を問うと、変更前も変更後も、暫定のメッセージ案とあわせて、コミット前に`claude-md-maintenance`の比較テストが要ると答えた。行動は変わらなかった。`rule-tester`は起動時に`.claude/CLAUDE.md`をReadするため、変更前の`paths`でもこのルールに行き着ける状態で、`AGENTS.md`を`paths`に足した効果は`rule-tester`では再現できない
- Readツールは`@`のimportを展開しない（2026-10-22）: `.claude/CLAUDE.md`をコピーしてReadすると、1行目に`@AGENTS.md`の文字列が返るだけだった。`omitClaudeMd: true`の`rule-tester`には、`AGENTS.md`を読む指示が要る
- Step2の比較テスト（2026-10-22）: 他の変更を退避し、「`.claude/hooks/record-check.sh`の判定条件を1つ書き換えた。コミットするまでの流れを具体的に答えて」を問うと、変更前も、比較テストではなくスクリプトの実行で確かめると答えたが、根拠はコミット済みのこのplanのDecision Logと、`plan-work-records`の過去の確認の記録で、実セッションでの発火の確認は「必要なら」としていた。変更後は`hooks-authoring`の確認を根拠に、発火すべき入力・発火すべきでない入力（書き換えた条件の両側）の直接実行と、実セッションでの発火の確認を、コミット前の必須の手順として挙げた。行動が変わったため変更を残す

## Decision Log

- 2026-10-22: hookの変更は`rule-tester`の比較テストではなく、スクリプトを実行するテストで確かめる。hookの挙動は入力に対して決まっており、モデルの解釈の差を見る比較テストでは確かめられないため
- 2026-10-22: `claude-md-maintenance`ルールの変更と`hooks-authoring`ルールの変更は、ユーザーの指示で別のブランチに分ける
- 2026-10-22: `claude-md-maintenance`ルールの手順の見出しと本文は、比較テストで行動が変わらなくても、対象（`.claude/CLAUDE.md`・`AGENTS.md`・`.claude/rules/`・`.claude/skills/`）を列記した形で残す（ユーザー指示）。旧見出し「新規ルール追加時の必須手順」は、人が読むと`.claude/rules/`だけが対象に読めるため
- 2026-10-22: `rule-tester`の、`AGENTS.md`を読む指示は残す。`omitClaudeMd: true`のためCLAUDE.mdはReadで読ませており、Readは`@AGENTS.md`を展開しないため

## Validation and Acceptance

- `claude-md-maintenance`ルールの`paths`に`AGENTS.md`があり、比較テストの手順の対象に`CLAUDE.md`・`AGENTS.md`・rules・skillが書かれている
- `hooks-authoring`ルールに、hookを変更したときの確認が書かれている
- 両方の変更で`claude-md-maintenance`ルールの比較テストを行い、結果を検証結果に記録している
