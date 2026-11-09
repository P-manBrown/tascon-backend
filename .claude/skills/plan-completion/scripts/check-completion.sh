#!/usr/bin/env bash
# Usage: check-completion.sh   (run from lefthook pre-commit, inside the repository)
# Checks that, after this commit, the index keeps the plan completion records
# and links intact. Reads the index (git show :<path>) and HEAD, never the
# working tree. The staged diff only decides which files to look at.
# Exit: 0 nothing wrong / 1 something to fix (one "file: reason" line each)
set -u

# Every check below reads Markdown with jq, so without it nothing can be checked.
# Fail here instead of passing silently.
command -v jq >/dev/null 2>&1 || { printf '%s\n' "check-completion.sh: jq is required but not installed" >&2; exit 1; }

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
lib_dir="$script_dir/lib"
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$top" || exit 1

active=.claude/plans/active
completed=.claude/plans/completed

if git rev-parse --verify -q HEAD >/dev/null; then
  base=HEAD
else
  base=$(git hash-object -t tree /dev/null)
fi

declare -A change=()
while IFS= read -r -d '' st && IFS= read -r -d '' path; do
  change[$path]=${st:0:1}
done < <(git diff --cached --no-renames --name-status -z "$base")

relevant=false
for path in "${!change[@]}"; do
  case "$path" in
    *.md | .claude/plans/* | .claude/specs/*) relevant=true ;;
  esac
  [ "${change[$path]}" = D ] && relevant=true
done
"$relevant" || exit 0

problems=()
problem() { problems+=("$1: $2"); }

in_index() { git cat-file -e ":$1" 2>/dev/null; }
index_text() { git show ":$1"; }
head_text() { git show "HEAD:$1"; }
jq_md() { jq -L "$lib_dir" "$@"; }

declare -A anchors_cache=()
# anchors_of <path>: anchors of the headings of an index Markdown file.
anchors_of() {
  if [ -z "${anchors_cache[$1]+set}" ]; then
    anchors_cache[$1]=$(index_text "$1" | jq_md -Rrs 'include "markdown"; md_anchors[]')
  fi
  printf '%s\n' "${anchors_cache[$1]}"
}

# target_problem <path> <anchor>: prints why the target is missing, or nothing.
target_problem() {
  local path=$1 anchor=$2
  if [ -z "$path" ]; then
    echo "points outside the repository"
  elif in_index "$path"; then
    case "$path" in
      *.md)
        if [ -n "$anchor" ] && ! anchors_of "$path" | grep -Fxq -- "$anchor"; then
          echo "has no heading for #$anchor in $path"
        fi
        ;;
    esac
  elif [ -z "$(git ls-files -- "$path/" | head -n 1)" ]; then
    echo "points to $path, which is not in the commit"
  fi
}

# links_of <md path>: "target<US>anchor<US>link" for each local link, where
# <US> is U+001F (a separator that read does not collapse, unlike a tab).
links_of() {
  index_text "$1" | jq_md -Rrs --arg file "$1" '
    include "markdown";
    ($file | split("/") | .[:-1] | join("/")) as $dir
    | md_links[] as $link
    | select($link | test("^([A-Za-z][A-Za-z0-9+.-]*:|//)") | not)
    | ($link | index("#")) as $hash
    | (if $hash == null then $link else $link[:$hash] end | sub("\\?.*$"; "") | url_decode) as $path
    | (if $hash == null then "" else $link[$hash + 1:] | url_decode end) as $anchor
    | (if $path == "" then $file
       elif ($path | startswith("/")) then $path[1:]
       else $dir + "/" + $path
       end | normalize_path) as $target
    | [($target // ""), $anchor, $link] | join("\u001f")'
}

declare -A deleted_active=() added_completed=()
for path in "${!change[@]}"; do
  case "$path" in
    "$active"/*/*.md | "$completed"/*/*.md) ;;
    "$active"/*.md)
      name=${path#"$active"/}
      [ "${change[$path]}" = D ] && deleted_active[$name]=1
      ;;
    "$completed"/*.md)
      name=${path#"$completed"/}
      [ "${change[$path]}" = A ] && added_completed[$name]=1
      ;;
  esac
done

moves=()
for name in "${!deleted_active[@]}"; do
  if [ -n "${added_completed[$name]+set}" ]; then
    moves+=("$name")
  else
    problem "$active/$name" "deleted without adding $completed/$name (move the plan instead of deleting it)"
  fi
done

# Rule 3: a plan is never both active and completed in the index.
for path in "${!change[@]}"; do
  case "$path" in
    "$active"/*/*.md | "$completed"/*/*.md) continue ;;
    "$active"/*.md) name=${path#"$active"/} ;;
    "$completed"/*.md) name=${path#"$completed"/} ;;
    *) continue ;;
  esac
  [ "${change[$path]}" = D ] && continue
  if in_index "$active/$name" && in_index "$completed/$name"; then
    problem "$completed/$name" "$active/$name is still in the commit"
  fi
done

# Rule 1: each move keeps the plan and has its completion records.
for name in "${moves[@]}"; do
  after_path="$completed/$name"
  while IFS=$'\x1f' read -r kind a b; do
    case "$kind" in
      E) problem "$after_path" "$a" ;;
      T)
        reason=$(target_problem "$(jq -rn --arg p "$a" -L "$lib_dir" 'include "markdown"; $p | normalize_path // ""')" "$b")
        [ -n "$reason" ] && problem "$after_path" "書き写した: $a${b:+#$b} $reason"
        ;;
    esac
  done < <(jq_md -rn --rawfile before <(head_text "$active/$name") --rawfile after <(index_text "$after_path") '
    include "markdown";
    def e($m): ["E", $m] | join("\u001f");
    ($before | plan_items("Decision Log")) as $old
    | ($after | plan_items("Decision Log")) as $new
    | (reduce $old[] as $o ({at: 0, ok: true};
         if .ok | not then .
         else ([range(.at; $new | length) | select($new[.].lines == $o.lines)] | first) as $i
           | if $i == null then .ok = false else .at = $i + 1 end
         end)
       | .ok) as $kept
    | (if $kept then empty else e("Decision Log items of the active plan are not all kept in the same order and wording") end),
      ($new | to_entries[]
       | (.key + 1) as $n | .value | transfer_records as $r
       | if ($r | length) != 1 then e("Decision Log item \($n) needs exactly one 書き写した: or 書き写さない: line, found \($r | length)")
         elif $r[0].kind == "書き写さない" then (if $r[0].value == "" then e("Decision Log item \($n) has an empty 書き写さない: reason") else empty end)
         else ([$r[0].value | scan("`([^`]+)`") | .[0]]) as $targets
           | if ($targets | length) == 0 then e("Decision Log item \($n) has no `path` in 書き写した:")
             else $targets[] | (index("#")) as $h
               | ["T", (if $h == null then . else .[:$h] end), (if $h == null then "" else .[$h + 1:] end)] | join("\u001f")
             end
         end),
      (if ($before | plan_section_lines("Validation and Acceptance"; ["結果", "根拠"]))
          != ($after | plan_section_lines("Validation and Acceptance"; ["結果", "根拠"]))
       then e("Validation and Acceptance differs from the active plan apart from 結果:/根拠: lines")
       else empty end),
      ($after | post_merge_items | to_entries[]
       | (.key + 1) as $n | .value.records as $r
       | ([$r[] | select(.kind == "結果")]) as $result
       | ([$r[] | select(.kind == "根拠")]) as $basis
       | (if ($result | length) != 1 or (["満たす", "満たさない", "未確認"] | index($result[0].value)) == null
          then e("post-merge item \($n) needs exactly one 結果: 満たす, 満たさない or 未確認") else empty end),
         (if ($basis | length) != 1 or $basis[0].value == ""
          then e("post-merge item \($n) needs exactly one non-empty 根拠:") else empty end))')
done

# Rule 4: other changes to plans keep what HEAD had.
for path in "${!change[@]}"; do
  case "$path" in
    "$active"/*/*.md | "$completed"/*/*.md) continue ;;
    "$completed"/*.md)
      if [ "${change[$path]}" = D ]; then
        problem "$path" "completed plans are kept, do not delete them"
        continue
      fi
      ;;
    "$active"/*.md) ;;
    *) continue ;;
  esac
  [ "${change[$path]}" = M ] || continue
  while IFS= read -r message; do
    problem "$path" "$message"
  done < <(jq_md -rn --rawfile old <(head_text "$path") --rawfile new <(index_text "$path") --arg completed "$( [[ $path == "$completed"/* ]] && echo yes)" '
    include "markdown";
    ($old | plan_items("Decision Log")) as $o
    | ($new | plan_items("Decision Log")) as $n
    | (if ($n | length) < ($o | length)
       then "Decision Log has \($n | length) items, fewer than the \($o | length) in HEAD" else empty end),
      (if $completed == "yes" then
         ($o | to_entries[] | select(.value | transfer_records | length > 0) | .key as $i
          | if ($n[$i] // {records: []} | transfer_records | length) != 1
            then "Decision Log item \($i + 1) lost its 書き写した:/書き写さない: line" else empty end),
         (($old | post_merge_items) as $po | ($new | post_merge_items) as $pn
          | $po | to_entries[] | .key as $i
          | (.value.records | map(.kind)) as $kinds
          | ("結果", "根拠") as $k
          | select($kinds | index($k))
          | if ([$pn[$i] // {records: []} | .records[] | select(.kind == $k)] | length) != 1
            then "post-merge item \($i + 1) lost its \($k): line" else empty end)
       else empty end)')
done

# Rule 5: a move keeps the specs.
if [ "${#moves[@]}" -gt 0 ]; then
  for path in "${!change[@]}"; do
    case "$path" in
      .claude/specs/*) [ "${change[$path]}" = D ] && problem "$path" "specs are not moved or deleted when a plan is completed" ;;
    esac
  done
fi

# Rule 6: links in added or changed Markdown, and links to deleted files.
declare -A deleted=() checked=()
for path in "${!change[@]}"; do
  case "${change[$path]}" in
    A | M)
      case "$path" in
        *.md)
          checked[$path]=1
          while IFS=$'\x1f' read -r target anchor link; do
            reason=$(target_problem "$target" "$anchor")
            [ -n "$reason" ] && problem "$path" "link ($link) $reason"
          done < <(links_of "$path")
          ;;
      esac
      ;;
    D) deleted[$path]=1 ;;
  esac
done
if [ "${#deleted[@]}" -gt 0 ]; then
  declare -A candidates=()
  for path in "${!deleted[@]}"; do
    while IFS= read -r file; do
      [ -n "$file" ] && candidates[$file]=1
    # A link may name the file percent-encoded, so Markdown that has "%" is a candidate too.
    done < <(git grep --cached -l -F -e "${path##*/}" -e '%' -- '*.md' 2>/dev/null)
  done
  for file in "${!candidates[@]}"; do
    [ -n "${checked[$file]+set}" ] && continue
    while IFS=$'\x1f' read -r target anchor link; do
      [ -n "$target" ] && [ -n "${deleted[$target]+set}" ] && problem "$file" "link ($link) points to $target, which this commit deletes"
    done < <(links_of "$file")
  done
fi

[ "${#problems[@]}" -eq 0 ] && exit 0
printf '%s\n' "${problems[@]}" | sort
printf '%s\n' "See \"完了の記録の書き方\" and \"検査が止めたとき\" in .claude/skills/plan-completion/SKILL.md."
exit 1
