#!/usr/bin/env bash
# One command to get renderLab running from a fresh clone.
#
#   ./run.sh                  # set up, build and run with OpenGL
#   ./run.sh metal            # ... with Metal
#   ./run.sh opengl --frames 120   # extra arguments go to RenderLab
#   ./run.sh test             # run the unit tests
#   ./run.sh metal --config debug   # debug build (default: --config release)
#   ./run.sh metal --log      # diagnostic logs to stderr (default: off); --log=debug adds FPS
#
# The app is built in release mode by default (optimized, so FPS numbers mean something).
# Tests default to debug; `./run.sh test --config release` also works.
#
# It runs these steps:
#   1. fetch the Dear ImGui submodule if it's missing
#   2. run scripts/doctor.sh and stop if a required check fails
#   3. swift run / swift test
set -euo pipefail

cd "$(dirname "$0")"

step() { printf "\n\033[1m==> %s\033[0m\n" "$1"; }

# No command, or only RenderLab flags (./run.sh --frames 30): default to OpenGL.
if [ $# -eq 0 ] || { [[ "$1" == -* ]] && [[ "$1" != -h && "$1" != --help ]]; }; then
    command=opengl
else
    command="$1"
    shift
fi

# Pull out --config release|debug (also --config=X); everything else goes to RenderLab / swift test.
config=""
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --config)
            [ $# -ge 2 ] || { echo "--config needs a value: release | debug" >&2; exit 2; }
            config="$2"
            shift 2
            ;;
        --config=*)
            config="${1#--config=}"
            shift
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done
case "$config" in
    "" | release | debug) ;;
    *) echo "unknown config '$config'. Use: --config release | --config debug" >&2; exit 2 ;;
esac
# bash 3.2 (macOS) treats an empty "${args[@]}" as unset under `set -u`; this form is safe.
set -- ${args[@]+"${args[@]}"}

case "$command" in
    opengl | metal | test) ;;
    -h | --help | help)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown command '$command'. Use: opengl | metal | test | help" >&2
        exit 2
        ;;
esac

if [ ! -f ThirdParty/imgui/imgui.h ]; then
    step "Fetching Dear ImGui submodule"
    git submodule update --init --recursive
fi

step "Checking system"
./scripts/doctor.sh --quick

case "$command" in
    test)
        # Swift Testing isn't importable with only the Command Line Tools selected; use Xcode's toolchain if present.
        if [[ "$(xcode-select -p 2>/dev/null)" == *CommandLineTools* && -d /Applications/Xcode.app ]]; then
            export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
        fi
        config="${config:-debug}"
        flags=()
        # The tests use @testable import, which release builds only allow with -enable-testing.
        [ "$config" = release ] && flags=(-Xswiftc -enable-testing)
        step "Running tests ($config)"
        swift test -c "$config" ${flags[@]+"${flags[@]}"} "$@"
        ;;
    opengl | metal)
        config="${config:-release}"
        step "Building and running RenderLab ($command, $config)"
        swift run -c "$config" RenderLab --backend "$command" "$@"
        ;;
esac
