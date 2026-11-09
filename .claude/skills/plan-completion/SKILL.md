---
name: plan-completion
description: 計画（`.claude/plans/`）の完了を判定し、完了した計画の完了の処理を行うスキル。「計画は完了した？」「完了の処理をして」等の指示があった場合、`gh pr merge`の後に完了の処理を促された場合に加え、計画の段のPRのRelated Documentsの印を書く場合にも使用する。
---

# plan-completion

計画の完了を、PR本文のRelated DocumentsのPlan行とGitHubのPRの状態だけで判定し、完了した計画の完了の処理を行う。スクリプトは`scripts/`にある。

## PR本文のRelated Documentsの印

- 計画の段のPRは、本文の`### Related Documents`に、その計画と設計を指す行を書く。形は`- ` + 印 + 半角の空白1つ + `Plan: ` + リポジトリの根からのパス（Specも同じ形）
- 印:
  - ✅: Planは、計画を最後まで終えたPR（計画の最後の段の、いちばん上のPR）と、完了の処理のPR（Plan行が`.claude/plans/completed/<name>.md`を指すPR）に付ける。Specは、その設計につく最後の計画の最後の段のPRと、その計画の完了の処理のPRに付ける
  - 🏃: それ以外の段のPR
  - ⬜: 計画・設計が無いPR。パスに`N/A`と書く（`- ⬜ Plan: N/A`・`- ⬜ Spec: N/A`）。行は省かない
- 取りやめたPRが計画を指したまま閉じていると、その計画は完了にならない。人が確かめて、そのPRの本文の印を直す

## 判定

空のフォルダで`scripts/judge-completion.sh --repo <owner>/<name>`を実行する。標準出力のJSONの`completed`は完了した計画、`missing_marker`は指すPRがすべてmainにマージ済みなのに✅が無い計画、`unreadable`は読めないPlan行。

- 終了コード0: `completed`の計画ごとに完了の処理を行う
- 4: `missing_marker`・`unreadable`をユーザーに知らせる。PRの本文は自動で直さない（✅を付けるべきPRか、取りやめたPRかは人が確かめる）。`completed`の計画の完了の処理は進めてよい
- 3: GitHubの読み取りが揃わなかった。完了の処理をせず、時間をおいて判定をやり直す
- 2・1: 呼び方の誤り・内部の誤り。原因を直して判定をやり直す

## 完了の処理

計画ごとに次を行う。リポジトリの外から判定を走らせて始めるときも、同じ手順で行う。

0. `scripts/find-completion-pr.sh --repo <owner>/<name> --plan <計画のファイル名から.mdを除いたもの>`で、その計画の完了の処理のPR（開いているPRで、Plan行が`.claude/plans/completed/<name>.md`を指すもの）を探す。番号が出たら、その計画には何もしない。終了コードが0でなければ始めない
1. `Validation and Acceptance`のうち「マージ後に判定」と明記した項目を、最新のmainをdetachした一時のworktreeで1件ずつ判定する。該当する項目がなければ判定しない
   - 満たさない項目、記述と実態が食い違う項目は、隠さずに記録と報告に含める
2. claude-memを検索し、この計画に関係する決定・ドキュメント化すべき内容・記録すべき教訓のうち、まだ記録されていないものを洗い出す
3. 洗い出した内容を、該当するドキュメントへ転記する
   - 転記候補は、claude-memの照会結果と、計画ファイル全体（`Decision Log`以外の注記・再開時の前提等を含む）から洗い出す。候補ごとに転記先、または転記しない理由を決める
   - 複数タスクを跨ぐ横断的な設計判断 → `docs/decisions/`へ個別ファイル化する。その計画固有の経緯は計画ファイルの`Decision Log`に追記する
   - 今すぐ対応しないが将来問題化しうる設計上の妥協・既知の制約 → `tech-debt-tracker` skillの手順で記録する
   - 恒久的な振る舞いルール・手順の変更、ユーザーの作業スタイル → `claude-md-maintenance`ルールの置き場所判断に従い、CLAUDE.md・`.claude/rules/*.md`・`.claude/skills/*/SKILL.md`・memoryのうち該当する場所へ反映する
4. コードの変更が`ARCHITECTURE.md`に影響を与える場合、`ARCHITECTURE.md`を更新する
5. 完了した計画がtech-debtに関連するものであれば`tech-debt-tracker` skillに従い、tech-debtも更新する
6. 計画を`.claude/plans/active/`から`.claude/plans/completed/`へ同じ名前で移し、「完了の記録の書き方」のとおり記録を書き足す。設計（`.claude/specs/`）は移さない。completedの計画は削除せず、実装判断の根拠として保持し続ける
7. 結果をユーザーへ報告する。手順ごとに、実施内容・判定と根拠・未実施の事項を示す。手順1は項目ごと、手順2・3は洗い出した候補ごとの扱いを全件示す

完了の処理の変更は、`git-spice-workflow` skillに従って完了の処理用に挿入したブランチでコミットし、PRにする。そのPRのRelated Documentsは`- ✅ Plan: .claude/plans/completed/<name>.md`と、その計画の設計があれば`- ✅ Spec: <設計のパス>`、無ければ`- ⬜ Spec: N/A`にする。

## 完了の記録の書き方

移した後の`.claude/plans/completed/<name>.md`の、各項目のすぐ下に入れ子で書き足す。項目の本文は書き換えない。

- `Decision Log`の各項目（トップレベルの`- `の行とその続き）に、次のどちらかをちょうど1行:
  - `  - 書き写した: <転記先>`: 転記先はリポジトリの根からのパスをバッククォートで囲む。見出しを指すときは`#アンカー`を付ける。複数なら`、`で区切る
  - `  - 書き写さない: <理由>`: 理由は空にしない
- `Validation and Acceptance`の「マージ後に判定」の各項目に、次を1行ずつ:
  - `  - 結果: 満たす`（または`満たさない`・`未確認`）
  - `  - 根拠: <確かめた方法と見たもの。満たさない・未確認ならその理由>`

## 検査が止めたとき

pre-commitの`scripts/check-completion.sh`は、コミットする内容（ステージ）と`HEAD`を読み、次のときにファイルと理由を出してコミットを止める。直すのは作業ツリーではなくステージの内容。

- 移した計画の`Decision Log`の項目が、移す前と同じ順・同じ文で残っていない → 項目を戻す。完了の記録の行と、この計画固有の経緯の項目は足してよい
- `Decision Log`の項目に完了の記録がちょうど1行ない、転記先がコミットに無い・その見出しが無い、理由が空 → 「完了の記録の書き方」のとおりに直す。転記先を先に作ってステージする
- `Validation and Acceptance`が、完了の記録の行を除いて移す前と違う → 移す前の文に戻す
- 「マージ後に判定」の項目に`結果:`・`根拠:`がちょうど1つずつない → 書き足す
- activeの計画を消したのに、同じ名前の計画がcompletedに無い。completedに移したのに、activeにも残っている → 消すのではなく移す。両方には残さない
- 計画の`Decision Log`の項目を減らした。completedの計画から完了の記録の行を消した → 減らさない。文の直しと転記先のリンクの直しはよい
- completedの計画を消した。計画を移すコミットで`.claude/specs/`のファイルを消した → 消さない
- Markdownのリンクの行き先・見出しがコミットに無い（このコミットで消したファイルを指すリンクを含む） → 行き先を直すか、消したファイルを戻す
