# ルール・hook変更時のテストの対象範囲

## Context/Purpose

`claude-md-maintenance`ルールの比較テスト（`rule-tester`で変更前後の挙動を比べる手順）は、見出しと本文が「ルールを追加・変更したら」となっていて、skill・`CLAUDE.md`が対象か読み取りにくい。ルートの`AGENTS.md`はルールの`paths`に入っておらず、変更しても手順が読み込まれない。

hookについては、`hooks-authoring`ルールに設計上の注意しかなく、変更後に何を確かめるかが書かれていない。hookは入力に対して決まった出力を返すため、`rule-tester`の比較テストではなく、スクリプトを実際に実行するテストで確かめる。

## 合意した方針

- `claude-md-maintenance`ルールの`paths`に`AGENTS.md`を足し、手順の見出しと本文の対象を`CLAUDE.md`・`AGENTS.md`・rules・skillと明示する
- `hooks-authoring`ルールに、hookを変更したときの確認（入力JSONをstdinへ与えた直接実行、発火すべきでない入力で何も出ないこと、`settings.json`へ登録した実セッションで発火すること）を足す
- 2つの変更は別のブランチに分ける

## Progress

- [x] Step1: `claude-md-maintenance`ルールの`paths`に`AGENTS.md`を足し、比較テストの手順の見出しと本文の対象を`CLAUDE.md`・`AGENTS.md`・rules・skillと明示する。比較テストを行う
  - 比較テストで行動が変わらず、変更を取り消した（結果は検証結果）
  - ユーザーの指示で、見出しを対象のファイル・フォルダを列記した名前にし、本文に対象を列記して変更し直した。手順を匂わせない質問で再テストし、行動は変わらなかったが、人が読んで対象が分かるよう変更を残す（Decision Log）
- [x] Step2: `hooks-authoring`ルールに、hookを変更したときの確認を足す。比較テストを行う
  - Step1のコミット（`6ae6215a`）の後、`docs/rule-test-scope`の上に`docs/hook-change-tests`を挿入して作業する
  - `58014430`としてコミットした。比較テストの変更前の状態が汚れていたため（検証結果）、Step3で比較テストの条件を直してから取り直す
- [x] Step3: 比較テストの条件を、Decision Log（2026-10-22、比較テストに混ぜるものの区分）のとおりに`claude-md-maintenance`ルールの手順と`rule-tester`の定義へ反映する。先に、`omitClaudeMd`のサブエージェントに`paths`付きのルールが自動で読み込まれるか、サブエージェントでSkillツールが使えるかを確かめる。反映したら比較テストを行い、Step2の比較テストを新しい条件で取り直す
  - 差し込みとSkillツールを確かめ（検証結果）、`rule-tester`の定義と手順の1・6を書き直した（未コミット）。起動中のセッションで新しい定義の`rule-tester`を起動すると、ツールは`Read`・`Grep`・`Glob`のままで、指示文も古い定義のものだった。エージェント定義はセッションの起動時に読み込まれるため、Claude Codeを起動し直してから比較テストを行う
  - 再開時の手順: 作業ツリーに未コミットの`.claude/agents/rule-tester.md`・`.claude/rules/claude-md-maintenance.md`・このplanの変更がある（`plan-branch-list-completion.md`の2行は前のplanの未コミット分で、この作業とは別）。まず`rule-tester`に使えるツールと定義の指示文を答えさせ、Skillがあり指示文が新しいことを確かめる。次の2つの比較テストを、`claude-md-maintenance`の手順で行う
    - 手順1・6の変更（対象: `claude-md-maintenance.md`）。期待する行動: 「`.claude/rules/controllers.md`に1行足した。コミットまでに何をするか」に、変更後は、変更後に期待する行動を先に1点決め、ルール名や手順の有無を直接問わないプロンプトを作ると答える
    - Step2の取り直し（対象: `hooks-authoring.md`、コミット済みのため、変更前は`git show 58014430^:.claude/rules/hooks-authoring.md`の内容を作業ツリーに書き、変更後は`git checkout -- .claude/rules/hooks-authoring.md`で戻す）。プロンプトはStep2と同じ。期待する行動: 変更後だけ、実セッションでの発火の確認をコミット前の必須の手順として挙げる
    - 手順1・6の変更のテストは済んだ。Step2の取り直しは、`rule-tester`が読み込みの制限を守らず、gitStatusからも変更が漏れたため中断した（検証結果）。制限は定義の`hooks`で強制することになった（Decision Log）。gitStatusからの漏れへの対策として、変更前のテストを変更前のコミットへdetachしたメインのcheckoutで行う案で進めることになった（Decision Log）
    - ガードのフック`.claude/hooks/rule-tester-guard.sh`と`rule-tester.md`のfrontmatterの`hooks`をCodexが実装し、直接実行で確かめた（検証結果）。`claude-md-maintenance`の手順2〜5をdetach方式に書き換えた（未コミット）。エージェント定義はセッション起動時に読み込まれるため、ガードの実セッションでの確認とテストは、Claude Codeを起動し直してから行う
    - 再開時の手順（2回目）: 未コミットは`rule-tester.md`・`rule-tester-guard.sh`（新規）・`claude-md-maintenance.md`・このplan（`plan-branch-list-completion.md`の2行は別の作業）。(1) `rule-tester`に`.claude/rules/controllers.md`のReadと、パスなしのGrepをさせ、ガードが拒否することをトランスクリプトで確かめる (2) 手順2〜5の変更の比較テスト（対象: `claude-md-maintenance.md`、未コミットのためdetachは不要）。プロンプト「`.claude/rules/controllers.md`に1行足した。その意図を書いたplanは先にコミットしてある。コミットまでに何をするか」、期待する行動: 変更後だけ、変更前の状態をplanのコミットより前へdetachして作ると答える (3) Step2の取り直し（対象: `hooks-authoring.md`）を新しい手順で行う。変更前は`58014430^`ではなく、このplanのStep2の方針を含む`6ae6215a`の1つ前（`6ae6215a^`）へdetachする。そのコミットにはガードのスクリプトがないため、detachの後に`rule-tester-guard.sh`を作業ツリーへ置き（退避前に`/tmp`以外のscratchpadへ写しておく）、テスト後に消してから`git switch -`で戻る
      - detach中に、lefthookやClaude Codeのフック（`plan-completion-check.sh`等）が想定外の動きをしないかも、このときに確かめて検証結果に書く
    - Step2の取り直しと、手順の変更の比較テストを終えた（検証結果）。ブランチは、ガードのフックを含むため`chore/rule-test-isolation`にした
    - 結果を検証結果に書いてから、`docs/hook-change-tests`の上に`chore/rule-test-isolation`を`--insert --no-restack`で作り、`rule-tester.md`・`claude-md-maintenance.md`・このplanをコミットする
- [x] Step4: `rule-tester`のガードに、`.claude/plans/rule-test-fixture.md`の1ファイルだけReadを通す例外を足す。`claude-md-maintenance`の比較テストの手順に、`rule-tester`でルールの差し込みやskillの呼び出しの場面を作れないときは、ダミーのファイル等で場面を作ってテストし、テストしないまま変更を残さないことを足す。ガードの確認（直接実行・実セッション）と、手順の追記の比較テストを行う。先に、`rule-tester`がダミーplanをReadしたときに`plans-maintenance`が差し込まれることを確かめる
  - ガードの例外の編集と直接実行の確認をCodexへ委譲した（未コミット、ブランチは`docs/drop-plan-branches-sections`の上に作る予定）
  - 直接実行を確かめた（検証結果）。scratchpadではなく`.claude/plans/rule-test-fixture.md`に中身のないダミーplan（`# テスト用plan`と空の`## Context/Purpose`）を置き（未追跡）、`rule-tester`にReadさせると、定義の本文の「`.claude/plans/`配下のファイルは読まない」に従ってReadを呼ばず、差し込みを確かめられなかった。定義の本文に、プロンプトで指示されたときだけ`rule-test-fixture.md`を読む例外を足す必要がある。Codexへの委譲はauto modeの判定で拒否されたため、ユーザーに判断を仰いでいる
  - ユーザーが定義の書き換えを許可し、Codexへ委譲した。ダミーplanはテストの時だけ作り、終わったら消す（常設しない、ユーザー確認）
  - 定義の書き換えの後、ダミーplanのReadで`plans-maintenance`が差し込まれることを確かめた（検証結果）。`claude-md-maintenance`の手順1の下に、場面を作れないときはダミーのファイル等で作る旨の追記をCodexへ委譲した（未コミット）
  - 追記の比較テストを終えた（検証結果）。ダミーplanは消した。`docs/drop-plan-branches-sections`の上に`chore/rule-test-fixture`を作り、ガード・`rule-tester`の定義・`claude-md-maintenance`・このplan、`plan-branch-config`のDecision Log・Step6の追記をコミットする

## 検証結果

- Step1の比較テスト（2026-10-22）: 他の変更を退避し、「ルートの`AGENTS.md`に『コントローラーのアクションは7つ以内にする』という1行を追加した。コミット前に何をする必要があるか」を問うと、変更前も変更後も、`claude-md-maintenance`の比較テストの手順を`AGENTS.md`を対象に行うと答えた（どちらも置き場所を`controllers.md`へ移す検討を先に挙げた）。行動が変わらなかったため、変更を取り消した。どちらの`rule-tester`も`claude-md-maintenance.md`を自分で読んで答えており、`paths`への`AGENTS.md`の追加（`AGENTS.md`を読んだときにルールが読み込まれるか）は、このプロンプトでは確かめられていない
- Step1の再テスト（2026-10-22）: 見出しを「CLAUDE.md・AGENTS.md・rules・skillsの作成・変更時の必須手順」にし対象を列記した変更で、「ルートの`AGENTS.md`の『1. 実装前に考える』の文言を少し直した。コミットメッセージ案を出して」を問うと、変更前も変更後も、暫定のメッセージ案とあわせて、コミット前に`claude-md-maintenance`の比較テストが要ると答えた。行動は変わらなかった。`rule-tester`は起動時に`.claude/CLAUDE.md`をReadするため、変更前の`paths`でもこのルールに行き着ける状態で、`AGENTS.md`を`paths`に足した効果は`rule-tester`では再現できない
- Readツールは`@`のimportを展開しない（2026-10-22）: `.claude/CLAUDE.md`をコピーしてReadすると、1行目に`@AGENTS.md`の文字列が返るだけだった。`omitClaudeMd: true`の`rule-tester`には、`AGENTS.md`を読む指示が要る
- Step2の比較テスト（2026-10-22）: 他の変更を退避し、「`.claude/hooks/record-check.sh`の判定条件を1つ書き換えた。コミットするまでの流れを具体的に答えて」を問うと、変更前も、比較テストではなくスクリプトの実行で確かめると答えたが、根拠はコミット済みのこのplanのDecision Logと、`plan-work-records`の過去の確認の記録で、実セッションでの発火の確認は「必要なら」としていた。変更後は`hooks-authoring`の確認を根拠に、発火すべき入力・発火すべきでない入力（書き換えた条件の両側）の直接実行と、実セッションでの発火の確認を、コミット前の必須の手順として挙げた。行動が変わったため変更を残す
  - このテストの変更前の状態は汚れていた。Step2の方針を書いたこのplanをStep1でコミットしていたため、`git stash`で退避されず、変更前の`rule-tester`がそれを読んで答えた。`rule-tester`は`.claude/plans/`・`docs/decisions/`も自分から探して読むため、コミット済みの記録から答えに行き着き、変更の効果を小さく見積もる
- `omitClaudeMd`のサブエージェントへの`paths`付きルールの差し込み（2026-10-22）: `rule-tester`に`.claude/rules/`を開かず`app/controllers/application_controller.rb`だけをReadさせると、Read直後に`controllers.md`と`code-comments.md`がsystem-reminderとして差し込まれた。トランスクリプトのツール呼び出しは、このファイルのReadだけだった。Readで`.claude/CLAUDE.md`を読むと、同じ仕組みで`paths`に`.claude/CLAUDE.md`を持つ`claude-md-maintenance`も差し込まれる（本番ではCLAUDE.mdはReadされないため、この差し込みは`rule-tester`にだけ起きる）
- サブエージェントのSkillツール（2026-10-22）: general-purposeのサブエージェントで、Skillツールから`execution-plan`を呼び出し、本文が読み込まれた（トランスクリプトに`"name":"Skill","input":{"skill":"execution-plan"}`）。スキル一覧には`execution-plan`・`git-spice-workflow`が載っていた
- 新しい定義の反映（2026-10-22、Claude Codeの起動し直し後）: `rule-tester`のツールは`Read`・`Skill`・`Grep`・`Glob`で、指示文も新しい定義のものだった
- 手順1・6の変更の比較テスト（2026-10-22、対象: `claude-md-maintenance.md`）: 「`.claude/rules/controllers.md`に1行足した。コミットするまでに何をするか」を問い、期待する行動を「変更後に期待する行動を先に1点決め、ルール名や手順の有無を直接問わないプロンプトを作る」とした。変更前は「違反しそうなプロンプトを1つ書き出す」とだけ答え、変更後は期待する行動を1点に絞り、本番でルールが読み込まれる場面のプロンプトにし、ルール名を直接問わないと答えた。判定も「変更前になく変更後にあるかだけ」と答えた。行動が変わったため変更を残す。どちらも`claude-md-maintenance`は`.claude/CLAUDE.md`のReadで差し込まれたもので、変更前は`git-spice-workflow`をSkillツールで呼び出していた。変更後は`.claude/rules/controllers.md`の有無をGlobで確かめていた（中身は開いていない）
- Step2の取り直しの変更前（2026-10-22）: 変更前の`hooks-authoring.md`を作業ツリーに書き、Step2と同じプロンプトで問うと、`rule-tester`は指示に反して`.claude/rules/`のファイル（`hooks-authoring.md`・`code-comments.md`・`plans-maintenance.md`）と`git-spice-workflow`のSKILL.mdを直接Readし、`.claude/`全体（`memory/`だけ除外）をGrepして`plan-work-records.md`の記述も根拠にした。さらに、起動時に差し込まれるgitStatusの直近のコミット（`58014430 docs: define checks for creating or changing hooks`）と`M .claude/rules/hooks-authoring.md`から、手順が足されたはずだと推測していた。指示による読み込みの制限は守られず、gitStatusからもテスト対象の変更が漏れるため、この結果は判定に使わない。変更後のテストは行っていない
- ガードのフックの直接実行（2026-10-22）: `bash -n`は通り、stdinに入力JSONを与えると、`.claude/rules/`・`skills/`・`plans/`・`memory/`のRead（絶対パス・相対パス・`../`を含むパス）と、リポジトリのルート・`.claude`・禁止ディレクトリを起点にするGrep・Globで拒否のJSONを出し、`.claude/CLAUDE.md`・`AGENTS.md`・`app/`配下のRead、`.claude/hooks`・`app`・`docs`を起点にするGrep・Glob、`.claude/rulesX`のような接頭辞だけ一致するパス、Skill、gitリポジトリ外のcwdでは何も出さなかった（Codexの確認とClaudeの再実行）。Globの`pattern`に`../`を含めて起点の外を指す場合は見ていない
- ガードのフックのcommandの直接実行（2026-10-22）: `rule-tester.md`のfrontmatterをYAMLとして読んだcommandを`bash -c`で実行すると、`CLAUDE_PROJECT_DIR`がこのリポジトリなら`.claude/rules/controllers.md`のReadで拒否のJSONを出し、スクリプトのない`/tmp/nonexistent`ならstderrに「rule-tester-guard.shを実行できないため、Read・Grep・Globを止めた」を出してexit 2になった。jqがない等、ファイルがない以外の失敗は試していない
- ガードの実セッションでの発火（2026-10-22、起動し直し後）: `rule-tester`に`.claude/rules/controllers.md`のReadとパスなしのGrepをさせると、どちらも`PreToolUse:Read hook error`・`PreToolUse:Grep hook error`としてガードの理由の文言で拒否された
- 手順2〜5の変更の比較テスト（2026-10-22、対象: `claude-md-maintenance.md`）: 「`.claude/rules/controllers.md`に1行足した。その意図を書いたplanは先にコミットしてある。コミットまでに何をするか」を問い、期待する行動を「変更前の状態をplanのコミットより前へdetachして作る」とした。変更前はstashだけで変更前後を作ると答え、detachには触れなかった。変更後は、planが最初に入ったコミットの1つ前へ`git switch --detach <コミット>^`で移って変更前を見て、`git switch -`で戻ると答え、`No local changes to save`のときはpopしないことも挙げた。行動が変わったため変更を残す。どちらもrules・`.claude`全体を開こうとした操作はガードに拒否された（変更前2回、変更後1回）
- Step2の取り直しの変更前（2026-10-22、`6ae6215a^`へdetach）: `rule-tester`が`.claude/rules/`・`.claude/skills/`・`.claude/plans/`のファイルを直接Readし、ガードは一度も発火せず、Skillツールも使わなかった。detach先の`.claude/agents/rule-tester.md`は古い定義（`hooks`・Skillなし）で、detachの後に作業ツリーへ今の定義を書き戻してから起動しても、ツールは`Read`・`Grep`・`Glob`、指示文も古い定義のままだった。エージェント定義はgitのHEADを切り替えたときに読み込み直され、作業ツリーの書き換えだけでは読み込み直されないとみられる（stashで定義のファイルが古くなったときは、新しい定義のままだった）。この結果は判定に使わない
  - `git switch -`で元のブランチへ戻し、stashを戻してから起動すると、ツールに`Skill`があり、指示文も新しい定義だった。どの操作で定義が読み込み直されるかを、定義に「回答の最後に『MARK1』と書く」という行を足して確かめた。作業ツリーで足しただけで起動すると、指示文に印はなかった。続けてファイルを変えずに別のブランチへ切り替えて戻してから起動すると、印の行が引用され、回答の最後にMARK1と書いた。
  - ただし、その後`6ae6215a^`へdetachして今の定義を作業ツリーに置き、同じ応答のうちにすぐ起動すると、印付きの定義（ディスク上にはもうない版）のままだった。1分ほど置いてから起動すると、ディスク上の今の定義（印なし）になっていた。定義はHEADの切り替えではなく、ファイルの変更から少し遅れて読み込み直され、変更の直後に起動すると前の定義で動くとみられる。仕組みは確かめておらず、変更の後に指示文を答えさせて、想定した定義で動いていることを確かめてから比較テストを行う
- Step2の取り直しの変更前（2026-10-22、やり直し）: `6ae6215a^`へdetachし、作業ツリーに今の`rule-tester`の定義とガードを置き、指示文を答えさせて今の定義で動くことを確かめてから、Step2と同じプロンプトで問うた。rulesを含む範囲のGlobはガードに3回拒否され、skillはSkillツールで呼び出し、`hooks-authoring`・`code-comments`は差し込みで受け取っていた。回答はブランチ作成・ステージ・コミットの手順だけで、スクリプトを直接実行して確かめることも、実セッションでの発火の確認も挙げなかった。detachの前後で、lefthookやClaude Codeのフックから余計な出力はなかった
- Step2の取り直しの変更後（2026-10-22）: `docs/hook-change-tests`へ戻し、ガードと定義以外の未コミット変更を退避して同じプロンプトで問うと、差し込まれた`hooks-authoring`の「作成・変更時の確認」を根拠に、発火すべき入力（書き換えた条件の両側を含む）の直接実行、`stop_hook_active: true`等の発火すべきでない入力で何も出ないこと、`settings.json`に登録した実セッションでの発火を、コミット前に必須の確認として挙げた。変更前にはどれもなかったため、Step2の変更は行動を変えている
- 手順3・4の追記（定義とガードを置き、指示文で確かめる）の比較テスト（2026-10-22、対象: `claude-md-maintenance.md`）: 手順2〜5のテストと同じプロンプトで、期待する行動を「detachの後、起動前に定義とガードを置いて今の定義を確かめる」とした。変更前は、退避で定義とガードが作業ツリーから消え、古い定義で動くおそれを懸念として挙げただけで、手順にはしなかった。変更後は`git restore --source=<元のブランチ> --worktree`で2つを置き、指示文を答えさせて確かめてから起動し、戻る前に2つを戻すと答えた。行動が変わったため変更を残す。変更後の`rule-tester`は、定義とガードが未コミットのときは`--source`で取り出せず、手順2の退避でも消えると指摘した。これは`rule-tester`自体を変えている間だけ起きることで、このplanのマージ後は定義とガードがコミット済みになるため、手順は変えない
- ガードの例外の直接実行（2026-10-22、Codexの確認とClaudeの再実行）: `.claude/plans/rule-test-fixture.md`のRead（絶対パス・相対パス・`active/../`経由）は何も出さず、`.claude/plans/active/plan-branch-config.md`・`rule-test-fixture.mdX`のRead、`rule-test-fixture.md`や`.claude/plans`を起点にしたGrep・Glob、`rule-test-fixture.md/../active/plan-branch-config.md`のRead、`.claude/rules/controllers.md`のReadは拒否のJSONを出した。`app/models/user.rb`のReadは何も出さなかった。`bash -n`を通った
- ダミーplanでの差し込み（2026-10-22、定義の書き換えの後）: `rule-tester`に定義の`.claude/plans/`の箇条を引用させると新しい文言（`rule-test-fixture.md`の例外つき）で、`.claude/plans/rule-test-fixture.md`をReadさせると、直後に`plans-maintenance.md`（と`gitkeep.md`・`.claude/CLAUDE.md`）が差し込まれた。`.claude/plans/active/plan-branch-config.md`は定義に従って読まなかった
- Step4の手順の追記の比較テスト（2026-10-22、対象: `claude-md-maintenance.md`）: 「`.claude/rules/plans-maintenance.md`（`paths`は`.claude/plans/**/*.md`だけ）に、planのProgressの書き方について1行足した。コミットまでに何をするか」を問い、期待する行動を「`.claude/plans/rule-test-fixture.md`にダミーのplanを置き、それを読ませるプロンプトでテストする」とした。変更前は、`rule-tester`は`.claude/plans/`を読めずルールが差し込まれないため差が出ないとし、テストの組み方をユーザーと決める必要があると答えた。変更後は、手順1の付記を根拠に、退避の後にダミーplanを置き、プロンプトでそれを読ませ、テストの後に消すと答えた。行動が変わったため変更を残す
  - 変更前・変更後とも、`rule-tester`の定義とガードは書き換える前の版（コミット済み）で取った。新しい定義には「`rule-test-fixture.md`は読んでよい」とあり、1回目の変更前テストで新しい定義を残すと、変更前なのに定義からダミーplanの方法を読み取って答えたため。本番で手順を読むのはメインのエージェントで、`rule-tester`の定義は持っていない。定義の切り替えのたびに、指示文を引用させて今の版で動いていることを確かめた。stashで戻した直後は読み込み直されず、`touch`で更新時刻を変えると読み込み直された
  - 定義を確かめるための`rule-tester`の起動が2回、auto modeの判定で拒否された。2回目はユーザーの許可を得て起動した

## Decision Log

- 2026-10-22: hookの変更は`rule-tester`の比較テストではなく、スクリプトを実行するテストで確かめる。hookの挙動は入力に対して決まっており、モデルの解釈の差を見る比較テストでは確かめられないため
- 2026-10-22: `claude-md-maintenance`ルールの変更と`hooks-authoring`ルールの変更は、ユーザーの指示で別のブランチに分ける
- 2026-10-22: `claude-md-maintenance`ルールの手順の見出しと本文は、比較テストで行動が変わらなくても、対象（`.claude/CLAUDE.md`・`AGENTS.md`・`.claude/rules/`・`.claude/skills/`）を列記した形で残す（ユーザー指示）。旧見出し「新規ルール追加時の必須手順」は、人が読むと`.claude/rules/`だけが対象に読めるため
- 2026-10-22: `rule-tester`の、`AGENTS.md`を読む指示は残す。`omitClaudeMd: true`のためCLAUDE.mdはReadで読ませており、Readは`@AGENTS.md`を展開しないため
- 2026-10-22: 比較テストで確かめるのは「共有された条件で作業するエージェントの行動が、その記述で変わるか」とし、次の区分で条件を決める（ユーザー同意）
  - 混ぜてはいけないもの: memory（個人のもので共有されず、memoryで正しく動くと必要な記述をノイズと誤判定する）、テスト対象の変更そのものの記録（その変更のplan・Decision Log・検証結果。コミット済みでも変更後の正解を変更前に教える）、変更した人の会話の文脈
  - あってよいもの: `CLAUDE.md`・`AGENTS.md`、テスト対象以外のルール・skill・コード（本番と同じ経路で読み込まれる場合）、変更と関係のない過去のplan・decisions
  - `rule-tester`で確かめられないもの: ルール・skillが読み込まれるか（`paths`・description）。`rule-tester`が自分から読みに行くと、本番で読み込まれない場面でも内容を知る
  - 判定に使わないもの: 言い回し、順番、変更と関係のない提案の有無。テストの前に変更後に期待する行動を1点書き、それが変更前になく変更後にあるかだけで判定する
  - 人が読むための明確化は、行動が変わらなくても残してよい区分として扱う
- 2026-10-22: `rule-tester`は`.claude/plans/`配下を一律に読まない。変更と関係のない過去のplanはあってよいものだが、テスト対象の変更の記録とを`rule-tester`が見分けられないため、混ぜてはいけないものを確実に外す側を取る
- 2026-10-22: `rule-tester`は`.claude/rules/`・`.claude/skills/`を自分で開かず、ルールは`paths`による差し込み、skillはSkillツールの呼び出しでだけ使う。`omitClaudeMd`のサブエージェントでも差し込みとSkillツールが働くことを確かめたため（検証結果）、本番と同じ経路で読み込まれるかも比較テストで見られる
- 2026-10-22: `rule-tester`の読み込みの制限は、指示ではなく定義の`hooks`のPreToolUseで強制する（ユーザー同意）。`.claude/rules/`・`.claude/skills/`・`.claude/plans/`・`.claude/memory/`のRead、それらを検索範囲に含むGrep・Globを拒否する。指示だけではStep2の取り直しで守られなかったため（検証結果）。定義の`hooks`が効くかは入れる前に確かめる
- 2026-10-22: 比較テストの変更前の状態は、未コミットの変更をすべて退避し、メインのcheckoutをテスト対象の変更の最初のコミットの1つ前（すべて未コミットならHEAD）へdetachして作る（ユーザー同意）。サブエージェントのgitStatusは起動時の状態が入るため、変更前のコミットへ移れば、コミット済みの変更や記録が漏れない。worktreeは使わない（`paths`で差し込まれるルールはメインのcheckoutのファイルのため、2026-10-20の決定のまま）
- 2026-10-22: `rule-tester`のガードのフックは、スクリプトを実行できないとき（detach先にスクリプトがない等）はexit 2でRead・Grep・Globを止める。止めないと、ガードが外れたまま比較テストが進み、気づけないため
- 2026-10-22: detachで変更前の状態を作るときは、`rule-tester`を起動する前に、元のブランチの`rule-tester`の定義とガードのスクリプトを作業ツリーへ置き、指示文を答えさせて今の定義で動いていることを確かめる。定義はファイルの変更から遅れて読み込み直され、detach先の古い定義（ガードなし）で動くことがあるため
- 2026-10-22: `rule-tester`でルールの差し込みやskillの呼び出しの場面を作れないときも、テストしないまま変更を残さず、ダミーのファイル等で場面を作ってテストする（ユーザー指摘）。`plan-branch-config`で、`paths`が`.claude/plans/**/*.md`だけの`plans-maintenance`は、ガードが`.claude/plans/`のReadを止めるため差し込まれず、比較テストができないまま変更を残していた。そのため、ガードに`.claude/plans/rule-test-fixture.md`の1ファイルだけReadを通す例外を足し、テストの時だけそこに中身のないダミーplanを置く（ユーザー同意）。ダミーには過去の決定が入らないので、ガードで防いでいる結果の汚れは起きない。gitでは管理せず、テストの後に消す

## Validation and Acceptance

- `claude-md-maintenance`ルールの`paths`に`AGENTS.md`があり、比較テストの手順の対象に`CLAUDE.md`・`AGENTS.md`・rules・skillが書かれている
- `hooks-authoring`ルールに、hookを変更したときの確認が書かれている
- 両方の変更で`claude-md-maintenance`ルールの比較テストを行い、結果を検証結果に記録している
- 比較テストの手順と`rule-tester`の定義が、Decision Logの比較テストに混ぜるものの区分を満たす
- `rule-tester`のガードが、`.claude/plans/rule-test-fixture.md`のReadだけを通し、それ以外の`.claude/plans/`のRead・検索は今までどおり止める。`rule-tester`がそのファイルをReadすると`plans-maintenance`が差し込まれる
- 比較テストの手順に、場面を作れないときはダミーのファイル等で作ってテストすることが書かれ、比較テストで行動の変化を確かめている
