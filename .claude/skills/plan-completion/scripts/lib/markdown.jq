# Markdown readers shared by judge-completion.sh, find-completion-pr.sh and the
# pre-commit checks in .lefthook/pre-commit/. Load with: jq -L <scripts/lib> 'include "markdown"; ...'
# Every function takes the whole Markdown text as its input unless noted.

# Lines of the text. CRLF counts as one line break, so a CR never becomes
# trailing whitespace of a line.
def md_lines: gsub("\r\n"; "\n") | split("\n");

def _fence_open($line):
  ($line | sub("^[ \t]+"; "")) as $t
  | if ($t | test("^`{3,}[^`]*$")) then {char: "`", len: ($t | capture("^(?<f>`+)").f | length)}
    elif ($t | test("^~{3,}")) then {char: "~", len: ($t | capture("^(?<f>~+)").f | length)}
    else null
    end;

def _fence_close($line; $fence):
  ($line | sub("^[ \t]+"; ""))
  | test("^" + (if $fence.char == "`" then "`" else "~" end) + "{" + ($fence.len | tostring) + ",}[ \t]*$");

# Input: array of lines. Output: array of booleans, true when the line is part
# of a fenced code block (the opening and closing lines included). A fence that
# never closes runs to the end of the text.
def fence_mask:
  reduce .[] as $line ({fence: null, mask: []};
    if .fence == null then
      _fence_open($line) as $open
      | if $open == null then .mask += [false] else .fence = $open | .mask += [true] end
    else
      (if _fence_close($line; .fence) then .fence = null else . end)
      | .mask += [true]
    end)
  | .mask;

# Array of {line, fenced} for every line of the text.
def md_marked_lines:
  md_lines as $lines
  | ($lines | fence_mask) as $mask
  | [range(0; $lines | length) | {line: $lines[.], fenced: $mask[.]}];

# Lines of the "### Related Documents" sections, from the line after the
# heading up to the next heading of level 1-3, both found outside fences.
def related_documents:
  reduce md_marked_lines[] as $x ({in: false, out: []};
    if ($x.fenced | not) and ($x.line == "### Related Documents") then .in = true
    elif ($x.fenced | not) and ($x.line | test("^#{1,3}[ \t]")) then .in = false
    elif .in then .out += [$x]
    else .
    end)
  | .out;

def _plan_line_re: "^- (?<mark>✅|🏃|⬜) Plan: (?<path>\\S+)$";

# Plan lines of the Related Documents sections as {mark, path}. U+FE0F is
# removed before matching, so "✅" and "✅\uFE0F" read the same.
def plan_lines:
  [related_documents[] | select(.fenced | not) | .line | gsub("\uFE0F"; "") | capture(_plan_line_re)];

# Lines of the Related Documents sections (outside fences) that contain
# "Plan:" but do not have the plan line format, as written.
def unreadable_lines:
  [related_documents[] | select(.fenced | not) | .line
   | select(test("Plan:"))
   | select(gsub("\uFE0F"; "") | test(_plan_line_re) | not)];

# Input: heading text. Output: the anchor GitHub generates for it (before the
# -1, -2 suffixes for repeated anchors).
def github_anchor:
  ascii_downcase | gsub("[^\\p{L}\\p{M}\\p{N}\\p{Pc} -]"; "") | gsub(" "; "-");

# Anchors of every heading outside fences, with -1, -2 for repeats.
def md_anchors:
  [md_marked_lines[] | select(.fenced | not) | .line
   | select(test("^#{1,6}[ \t]"))
   | sub("^#{1,6}[ \t]+"; "") | sub("[ \t]+#+[ \t]*$"; "") | sub("[ \t]+$"; "")
   | github_anchor]
  | reduce .[] as $a ({seen: {}, out: []};
      (.seen[$a] // 0) as $n
      | .out += [if $n == 0 then $a else "\($a)-\($n)" end]
      | .seen[$a] = $n + 1)
  | .out;

# Destinations of inline links "[..](..)" and reference definitions
# "[..]: .." outside fences and outside inline code spans.
def md_links:
  [md_marked_lines[] | select(.fenced | not) | .line
   | gsub("(?<t>`+).*?\\k<t>"; "")
   | (if test("^ {0,3}\\[[^\\]]+\\]:[ \t]*\\S")
      then capture("^ {0,3}\\[[^\\]]+\\]:[ \t]*<?(?<d>[^ \t>]+)").d
      else empty
      end),
     (scan("\\]\\(<?([^)<> \t]+)>?(?:[ \t]+\"[^\"]*\")?\\)") | .[0])];

def _hex_byte: ascii_downcase | explode | map(if . >= 97 then . - 87 else . - 48 end) | .[0] * 16 + .[1];

def _utf8_decode:
  reduce .[] as $b ({cps: [], cur: 0, need: 0};
    if .need > 0 then .cur = .cur * 64 + ($b % 64) | .need -= 1
      | if .need == 0 then .cps += [.cur] else . end
    elif $b < 128 then .cps += [$b]
    elif $b >= 240 then .cur = $b % 8 | .need = 3
    elif $b >= 224 then .cur = $b % 16 | .need = 2
    else .cur = $b % 32 | .need = 1
    end)
  | .cps | implode;

# Input: a percent-encoded string. Output: the decoded string (UTF-8).
def url_decode:
  [scan("(?:%[0-9A-Fa-f]{2})+|[^%]+|%") as $t
   | if ($t | test("^%[0-9A-Fa-f]{2}"))
     then [$t | scan("%([0-9A-Fa-f]{2})") | .[0] | _hex_byte] | _utf8_decode
     else $t
     end]
  | join("");

# Input: a path relative to the repository root that may contain "." and
# ".." segments. Output: the normalized path, or null when it leaves the root.
def normalize_path:
  reduce (split("/")[] | select(. != "" and . != ".")) as $s ([];
    if . == null then null
    elif $s == ".." then (if length == 0 then null else .[:-1] end)
    else . + [$s]
    end)
  | if . == null then null else join("/") end;


def _record_re: "^[ \t]+- (?<kind>書き写した|書き写さない|結果|根拠):(?<value>.*)$";

# Items of the plan section "## <name>". An item is a top-level "- " line with
# the lines after it up to the next top-level "- " line or heading of level
# 1-2. Output: array of {lines, records}: lines are the item's lines without
# its completion record lines and without trailing blank lines; records are
# the completion record lines as {kind, value} (kind: 書き写した, 書き写さない,
# 結果 or 根拠; value trimmed). Lines before the first item are not items.
def plan_items($name):
  reduce md_marked_lines[] as $x ({in: false, items: []};
    if ($x.fenced | not) and ($x.line | test("^#{1,2}[ \t]")) then .in = ($x.line == "## " + $name)
    elif .in | not then .
    elif ($x.fenced | not) and ($x.line | test("^- ")) then .items += [{lines: [$x.line], records: []}]
    elif (.items | length) == 0 then .
    elif ($x.fenced | not) and ($x.line | test(_record_re))
      then .items[-1].records += [$x.line | capture(_record_re) | .value |= (sub("^[ \t]+"; "") | sub("[ \t]+$"; ""))]
    else .items[-1].lines += [$x.line]
    end)
  | .items
  | map(.lines |= until(length == 0 or (.[-1] | test("^[ \t]*$") | not); .[:-1]));

# Lines of the plan section "## <name>" (heading excluded) without the
# completion record lines of the given kinds.
def plan_section_lines($name; $kinds):
  reduce md_marked_lines[] as $x ({in: false, out: []};
    if ($x.fenced | not) and ($x.line | test("^#{1,2}[ \t]")) then .in = ($x.line == "## " + $name)
    elif .in | not then .
    elif ($x.fenced | not) and ($x.line | test(_record_re)) and (($x.line | capture(_record_re).kind) as $k | $kinds | index($k))
      then .
    else .out += [$x.line]
    end)
  | .out;

# Items of "## Validation and Acceptance" that say "マージ後に判定".
def post_merge_items:
  plan_items("Validation and Acceptance") | map(select(any(.lines[]; contains("マージ後に判定"))));

def transfer_records: [.records[] | select(.kind == "書き写した" or .kind == "書き写さない")];
