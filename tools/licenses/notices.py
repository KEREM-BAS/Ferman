"""Reduces cargo-about's JSON to the Rust notices the app ships.

Usage: python3 -I tools/licenses/notices.py <about.json> <tree.txt> <crates.json> [--check]

<tree.txt> is `cargo tree -p ferman-api --features frb -e normal --prefix none -f '{p}'` for each
desktop target, one after the other: the crates that ship. cargo-about resolves features for all
targets at once and lists a few crates no target links (windows-core, which only macOS's features
would pull in on Windows), so its licences are kept for the shipped crates alone, and a shipped
crate without a licence fails.

Writes, or with --check compares, the asset `registerLicenses()` reads: each licence text once with
the crates that carry it ("name version"), and nothing else, so no build path reaches the app.
"""

import json
import sys


def shipped(tree):
    crates = set()
    for line in tree.splitlines():
        words = line.split()
        if len(words) >= 2 and words[1].startswith("v") and not words[0].startswith("ferman-"):
            crates.add(f"{words[0]} {words[1][1:]}")
    return crates


def notices(about, ships):
    licences = []
    covered = set()
    for licence in about["licenses"]:
        crates = sorted(
            {f"{use['crate']['name']} {use['crate']['version']}" for use in licence["used_by"]}
            & ships
        )
        if crates:
            covered.update(crates)
            licences.append({"id": licence["id"], "crates": crates, "text": licence["text"]})
    if ships - covered:
        sys.exit(f"no licence found for {sorted(ships - covered)}")
    licences.sort(key=lambda licence: (licence["id"], licence["crates"]))
    return json.dumps({"licences": licences}, ensure_ascii=False, indent=1) + "\n"


def main(argv):
    if len(argv) not in (4, 5) or (len(argv) == 5 and argv[4] != "--check"):
        sys.exit(__doc__)
    with open(argv[1], encoding="utf-8") as about, open(argv[2], encoding="utf-8") as tree:
        text = notices(json.load(about), shipped(tree.read()))
    if len(argv) == 5:
        try:
            with open(argv[3], encoding="utf-8") as committed:
                current = committed.read() == text
        except FileNotFoundError:
            current = False
        if not current:
            sys.exit(f"{argv[3]} is stale: run bash tools/licenses/generate.sh")
        return
    with open(argv[3], "w", encoding="utf-8") as target:
        target.write(text)


if __name__ == "__main__":
    main(sys.argv)
