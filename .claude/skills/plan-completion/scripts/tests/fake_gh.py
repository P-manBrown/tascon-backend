"""Stand-in for `gh` in the tests.

Appends its arguments as one JSON line to $FAKE_GH_LOG, then answers from the
JSON file at $FAKE_GH_CONFIG: {"<endpoint>": {"stdout": "...", "stderr": "...", "exit": 0}}.
"""

import json
import os
import sys


def main(args):
    with open(os.environ["FAKE_GH_LOG"], "a", encoding="utf-8") as log:
        log.write(json.dumps(args) + "\n")
    with open(os.environ["FAKE_GH_CONFIG"], encoding="utf-8") as config_file:
        config = json.load(config_file)
    if len(args) != 2 or args[0] != "api":
        sys.stderr.write(f"fake gh: unexpected arguments {args}\n")
        return 1
    response = config.get(args[1])
    if response is None:
        sys.stderr.write(f"fake gh: no response for {args[1]}\n")
        return 1
    sys.stdout.buffer.write(response.get("stdout", "").encode("utf-8"))
    sys.stderr.buffer.write(response.get("stderr", "").encode("utf-8"))
    return response.get("exit", 0)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
