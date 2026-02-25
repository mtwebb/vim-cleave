#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: test/fuzz/reduce_reflow_failure.sh FAILURE.txt [FAILURE.meta] [OUT.txt]

The reducer removes lines while preserving the failure, producing a compact
fixture that can be promoted to deterministic regressions.
EOF
}

escape_for_vim() {
    printf "%s" "$1" | sed "s/'/''/g"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    usage
    exit 2
fi

FAILURE_FILE="$1"
META_FILE="${2:-${FAILURE_FILE%.txt}.meta}"
OUTPUT_FILE="${3:-test/fixtures/regressions/$(basename "${FAILURE_FILE%.txt}")_reduced.txt}"

if [ ! -f "$FAILURE_FILE" ]; then
    echo "Failure file not found: $FAILURE_FILE" >&2
    exit 2
fi

SEED=0
CLEAVE_COL=40
WIDTH=20
SIDE=left
MODE=ragged

if [ -f "$META_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            seed) SEED="$value" ;;
            cleave_col) CLEAVE_COL="$value" ;;
            width) WIDTH="$value" ;;
            side) SIDE="$value" ;;
            mode) MODE="$value" ;;
        esac
    done < "$META_FILE"
fi

if ! printf "%s" "$CLEAVE_COL" | grep -Eq '^[0-9]+$'; then
    echo "Invalid cleave_col in metadata: $CLEAVE_COL" >&2
    exit 2
fi
if ! printf "%s" "$WIDTH" | grep -Eq '^[0-9]+$'; then
    echo "Invalid width in metadata: $WIDTH" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CANDIDATE="$TMP_DIR/candidate.txt"
cp "$FAILURE_FILE" "$CANDIDATE"

run_case() {
    local case_file="$1"
    local escaped_case
    local escaped_side
    local escaped_mode
    escaped_case="$(escape_for_vim "$case_file")"
    escaped_side="$(escape_for_vim "$SIDE")"
    escaped_mode="$(escape_for_vim "$MODE")"

    if vim -u NONE -es \
        -c "let g:cleave_fuzz_seed=${SEED}" \
        -c "let g:cleave_fuzz_iterations=1" \
        -c "let g:cleave_fuzz_replay_file='${escaped_case}'" \
        -c "let g:cleave_fuzz_replay_cleave_col=${CLEAVE_COL}" \
        -c "let g:cleave_fuzz_replay_width=${WIDTH}" \
        -c "let g:cleave_fuzz_replay_side='${escaped_side}'" \
        -c "let g:cleave_fuzz_replay_mode='${escaped_mode}'" \
        -c "source test/fuzz/reflow_fuzz.vim" \
        -c "if RunReflowFuzz() | cquit 1 | endif" \
        -c "qa!" >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

echo "Checking reproducibility before reduction..."
if ! run_case "$CANDIDATE"; then
    echo "Failure no longer reproduces with metadata parameters." >&2
    exit 1
fi

echo "Reducing failure case..."
CHANGED=1
while [ "$CHANGED" -eq 1 ]; do
    CHANGED=0
    LINE_COUNT="$(wc -l < "$CANDIDATE")"
    if [ "$LINE_COUNT" -le 1 ]; then
        break
    fi

    for ((line_no = 1; line_no <= LINE_COUNT; line_no++)); do
        TRIAL="$TMP_DIR/trial.txt"
        awk -v drop="$line_no" 'NR != drop' "$CANDIDATE" > "$TRIAL"

        if [ ! -s "$TRIAL" ]; then
            continue
        fi

        if run_case "$TRIAL"; then
            mv "$TRIAL" "$CANDIDATE"
            CHANGED=1
            break
        fi
    done
done

mkdir -p "$(dirname "$OUTPUT_FILE")"
cp "$CANDIDATE" "$OUTPUT_FILE"

OUTPUT_META="${OUTPUT_FILE%.txt}.meta"
cat > "$OUTPUT_META" <<EOF
seed=$SEED
cleave_col=$CLEAVE_COL
width=$WIDTH
side=$SIDE
mode=$MODE
source_case=$FAILURE_FILE
source_meta=$META_FILE
EOF

echo "Reduced fixture written to: $OUTPUT_FILE"
echo "Metadata written to: $OUTPUT_META"
echo "Replay command:"
echo "  test/test_reflow_fuzz.sh --replay $OUTPUT_FILE --meta $OUTPUT_META"
