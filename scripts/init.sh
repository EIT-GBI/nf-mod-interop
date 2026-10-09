#!/usr/bin/env bash
# Scaffold this template into a concrete nf-mod-<name> module.
# Usage: ./scripts/init.sh <name> [subcommand]
#
# Each process lives in its own <subcommand>/ folder and is named
# <NAME>_<SUBCOMMAND> (modules/samtools/sort/main.nf -> SAMTOOLS_SORT).
# <subcommand> defaults to <name>, the convention for single-command tools
# (nf-mod-fastqc -> fastqc/main.nf -> FASTQC_FASTQC). Add more subcommands
# afterwards by copying that folder.

set -euo pipefail

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "usage: $0 <name> [subcommand]"
  exit 1
fi
SUB="${2:-$NAME}"

# Process names cannot contain '-', so nf-mod-foo-bar gives FOO_BAR_*.
LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
LOWER_ID=$(echo "$LOWER" | tr '-' '_')   # for identifiers, e.g. emit names
UPPER=$(echo "$NAME" | tr '[:lower:]-' '[:upper:]_')
SUB_LOWER=$(echo "$SUB" | tr '[:upper:]' '[:lower:]')
SUB_UPPER=$(echo "$SUB" | tr '[:lower:]-' '[:upper:]_')
PROCESS="${UPPER}_${SUB_UPPER}"
PROCESS_LOWER=$(echo "$PROCESS" | tr '[:upper:]' '[:lower:]')

# Every tracked file that still carries a template token, bar this scaffolding.
FILES=$(git grep -l -e '__NAME' -e '__SUB__' -e '__PROCESS' -- . \
  ':!scripts/init.sh' ':!.github/workflows/init.yml')

# Longer tokens first, so none is left half-replaced.
for f in $FILES; do
  sed -e "s/__PROCESS_LOWER__/$PROCESS_LOWER/g" \
      -e "s/__PROCESS__/$PROCESS/g" \
      -e "s/__NAME_UPPER__/$UPPER/g" \
      -e "s/__NAME_ID__/$LOWER_ID/g" \
      -e "s/__NAME__/$LOWER/g" \
      -e "s/__SUB__/$SUB_LOWER/g" \
      "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
done

git mv __SUB__ "$SUB_LOWER"

# Strip the template-usage block from README.md.
sed '/<!-- TEMPLATE:START -->/,/<!-- TEMPLATE:END -->/d' README.md > README.md.tmp
mv README.md.tmp README.md

# Remove template-only scaffolding from the new repo.
git rm -q -f --ignore-unmatch scripts/init.sh .github/workflows/init.yml
rmdir scripts 2>/dev/null || true

echo "Scaffolded nf-mod-$LOWER with process $PROCESS in $SUB_LOWER/."
