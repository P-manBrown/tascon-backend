# Readers of pull request bodies for merge-stack.sh. Load with
#   jq -L <plan-completion/scripts/lib> -L <git-spice-workflow/scripts/lib> 'include "pr-body"; ...'
# The first path provides markdown.jq, which this module includes.
include "markdown";

# Lines of the "### Testing" sections as {line, fenced}, from the line after
# the heading up to the next heading of level 1-3, both found outside fences.
def testing_section:
  reduce md_marked_lines[] as $x ({in: false, out: []};
    if ($x.fenced | not) and ($x.line == "### Testing") then .in = true
    elif ($x.fenced | not) and ($x.line | test("^#{1,3}[ \t]")) then .in = false
    elif .in then .out += [$x]
    else .
    end)
  | .out;

# True when a line of the Testing sections outside fences has a word of 7 to
# 40 hexadecimal digits, not next to another letter or digit, that is the
# beginning of $sha (compared in lower case).
def has_head_record($sha):
  ($sha | ascii_downcase) as $head
  | any(testing_section[] | select(.fenced | not) | .line
        | scan("(?<![0-9A-Za-z])[0-9A-Fa-f]{7,40}(?![0-9A-Za-z])")
        | ascii_downcase;
        . as $word | $head | startswith($word));
