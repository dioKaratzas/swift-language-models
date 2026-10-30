#!/bin/bash
# Compares the catalog snapshots with the ones at a git ref and decides the release the changes need:
#
#   major  a model's static is deleted, a model loses effort levels, or a word or effort set is deleted;
#   minor  a model is added or newly deprecated (retiring or removed), a model gains effort levels, or a word or
#          effort set is added or newly deprecated;
#   patch  anything else in the snapshots or generated code changes, such as limits, names, dates or cache flags;
#   none   nothing changed.
#
# Prints `bump=<level>` and `schema-changed=<true|false>` for $GITHUB_OUTPUT, and writes the reasons as Markdown to
# the summary file.
#
# Usage: catalog-changes.sh <base-ref> <summary-file>
set -euo pipefail

base=$1
summary=$2

schema_changed=false
git diff --quiet "$base" -- 'Catalogs/*.schema.json' || schema_changed=true

if git diff --quiet "$base" -- Catalogs Sources; then
    : > "$summary"
    echo "bump=none"
    echo "schema-changed=$schema_changed"
    exit 0
fi

# Reads the snapshot at the base ref as $old and the current one as input; prints "<level><tab><reason>" lines.
read -r -d '' changes <<'JQ' || true
def entries:
    [ (.vocabularies // {} | to_entries[] | .key as $v | .value[]
        | {name: "\($v) word `\(.word)`", removed: (.removedOn != null)}),
      ((.efforts // [])[] | {name: "effort `\(.word)`", removed: (.removedOn != null)}),
      ((.effortSets // [])[] | {name: "effort set `\(.words | join(" "))`", removed: (.removedOn != null)}) ];
def statics: [(.models // [])[].id, (.removed // [])[].model.id];
def deprecated: [((.models // [])[] | select(.expirationDate != null) | .id), (.removed // [])[].model.id];
def models: (.models // []) | map({key: .id, value: .}) | from_entries;

($old[0] // {}) as $o
| ($o | entries) as $oe | (entries) as $ne
| ($o | models) as $om | (models) as $nm
| (
    ((($o | statics) - statics)[] | ["major", "Deletes the static for `\(.)`."]),
    ((([$oe[].name] - [$ne[].name]))[] | ["major", "Deletes the \(.)."]),
    (($om | keys[]) as $id | select($nm[$id] != null)
        | (($om[$id].reasoningEfforts // []) - ($nm[$id].reasoningEfforts // [])) as $lost
        | select($lost | length > 0)
        | ["major", "Removes effort levels from `\($id)`: \($lost | join(", "))."]),
    ((statics - ($o | statics))[] | ["minor", "Adds `\(.)`."]),
    ((deprecated - ($o | deprecated))[] | ["minor", "Deprecates `\(.)`."]),
    (([$ne[] | select(.removed | not) | .name] - [$oe[].name])[] | ["minor", "Adds the \(.)."]),
    (([$ne[] | select(.removed) | .name] - [$oe[] | select(.removed) | .name])[]
        | select(. as $name | [$oe[].name] | index($name)) | ["minor", "Deprecates the \(.)."]),
    (($om | keys[]) as $id | select($nm[$id] != null)
        | (($nm[$id].reasoningEfforts // []) - ($om[$id].reasoningEfforts // [])) as $gained
        | select($gained | length > 0)
        | ["minor", "Adds effort levels to `\($id)`: \($gained | join(", "))."]),
    (($om | keys[]) as $id | select($nm[$id] != null and $nm[$id] != $om[$id])
        | [($om[$id] + $nm[$id]) | keys[] | select($om[$id][.] != $nm[$id][.])] as $fields
        | ["patch", "Changes `\($id)`: \($fields | join(", "))."])
  )
| @tsv
JQ

reasons=""
for snapshot in Catalogs/*.json; do
    [[ $snapshot == *.schema.json ]] && continue
    reasons+=$(jq -r --slurpfile old <(git show "$base:$snapshot" 2>/dev/null || echo '{}') "$changes" "$snapshot")
    reasons+=$'\n'
done

if grep -q '^major' <<< "$reasons"; then
    bump=major
elif grep -q '^minor' <<< "$reasons"; then
    bump=minor
else
    bump=patch
fi

api_changes=$(grep -E '^(major|minor)' <<< "$reasons" | cut -f2 | sed 's/^/- /' || true)
data_changes=$(grep '^patch' <<< "$reasons" | cut -f2 | sed 's/^/- /' || true)
{
    echo "**Release:** \`$bump\`"
    if [ -n "$api_changes" ]; then
        printf '\n%s\n' "$api_changes"
    fi
    if [ -n "$data_changes" ]; then
        printf '\n<details><summary>Models with changed data: %s</summary>\n\n%s\n\n</details>\n' \
            "$(wc -l <<< "$data_changes" | tr -d ' ')" "$data_changes"
    fi
} > "$summary"

echo "bump=$bump"
echo "schema-changed=$schema_changed"
