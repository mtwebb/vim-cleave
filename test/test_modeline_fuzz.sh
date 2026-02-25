#!/bin/bash

set -u
set -o pipefail

ITERATIONS="${ITERATIONS:-500}"
SEED="${SEED:-$(date +%s)}"
REPLAY_FILE="${REPLAY_FILE:-}"
REPLAY_META="${REPLAY_META:-}"

usage() {
    cat <<'EOF'
Usage: test/test_modeline_fuzz.sh [options]

Options:
  --iterations N    Number of generated cases (default: 500)
  --seed N          Deterministic random seed (default: current epoch)
  --replay FILE     Replay one saved failure case (.txt)
  --meta FILE       Optional sidecar metadata file for replay
EOF
}

escape_for_vim() {
    printf "%s" "$1" | sed "s/'/''/g"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --seed)
            SEED="$2"
            shift 2
            ;;
        --replay)
            REPLAY_FILE="$2"
            shift 2
            ;;
        --meta)
            REPLAY_META="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if ! printf "%s" "$ITERATIONS" | grep -Eq '^[0-9]+$'; then
    echo "Invalid iteration count: $ITERATIONS" >&2
    exit 2
fi
if ! printf "%s" "$SEED" | grep -Eq '^[0-9]+$'; then
    echo "Invalid seed: $SEED" >&2
    exit 2
fi

if [ -n "$REPLAY_FILE" ] && [ ! -f "$REPLAY_FILE" ]; then
    echo "Replay file not found: $REPLAY_FILE" >&2
    exit 2
fi
if [ -n "$REPLAY_META" ] && [ ! -f "$REPLAY_META" ]; then
    echo "Replay metadata file not found: $REPLAY_META" >&2
    exit 2
fi

echo "Running Cleave modeline fuzz tests"
echo "  seed: $SEED"
echo "  iterations: $ITERATIONS"
if [ -n "$REPLAY_FILE" ]; then
    echo "  replay: $REPLAY_FILE"
fi

VIM_CMD=(
    vim -u NONE -es
    -c "let g:cleave_fuzz_seed=${SEED}"
    -c "let g:cleave_fuzz_iterations=${ITERATIONS}"
    -c "let g:cleave_fuzz_fail_dir='test/fixtures/failures'"
)

if [ -n "$REPLAY_FILE" ]; then
    ESCAPED_REPLAY="$(escape_for_vim "$REPLAY_FILE")"
    VIM_CMD+=(
        -c "let g:cleave_fuzz_replay_file='${ESCAPED_REPLAY}'"
    )
fi

if [ -n "$REPLAY_META" ]; then
    ESCAPED_META="$(escape_for_vim "$REPLAY_META")"
    VIM_CMD+=(
        -c "let g:cleave_fuzz_replay_meta='${ESCAPED_META}'"
    )
fi

VIM_CMD+=(
    -c "source test/fuzz/modeline_fuzz.vim"
    -c "if RunModelineFuzz() | cquit 1 | endif"
    -c "qa!"
)

if "${VIM_CMD[@]}"; then
    echo "Modeline fuzz tests passed."
    exit 0
fi

echo "Modeline fuzz tests FAILED."
if [ -z "$REPLAY_FILE" ]; then
    echo "Re-run with:"
    echo "  test/test_modeline_fuzz.sh --seed $SEED --iterations $ITERATIONS"
fi
echo "Inspect generated failures in test/fixtures/failures/."
exit 1
