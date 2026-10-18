#!/usr/bin/env bash
# renderLab system check. Run before building:
#   ./scripts/doctor.sh           # full report, including GPU details
#   ./scripts/doctor.sh --quick   # skip the slow GPU query (system_profiler, ~1-2 s); run.sh uses this
#
# Prints one line per check and exits non-zero if a required check fails.
set -u

cd "$(dirname "$0")/.."

quick=0
[ "${1:-}" = "--quick" ] && quick=1

MIN_MACOS="13.0"
MIN_SWIFT="6.0"

if [ -t 1 ]; then
    GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
    GREEN=""; RED=""; YELLOW=""; DIM=""; BOLD=""; RESET=""
fi

failures=0
warnings=0

pass() { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${DIM}→ %s${RESET}\n" "$2"; failures=$((failures + 1)); }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${DIM}→ %s${RESET}\n" "$2"; warnings=$((warnings + 1)); }
info() { printf "  ${DIM}·${RESET} %s\n" "$1"; }
section() { printf "\n${BOLD}%s${RESET}\n" "$1"; }

# version_ge A B: true if version A >= version B (numeric, dot-separated).
version_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]
}

section "System"

macos="$(sw_vers -productVersion 2>/dev/null || echo 0)"
if version_ge "$macos" "$MIN_MACOS"; then
    pass "macOS $macos (>= $MIN_MACOS)"
else
    fail "macOS $macos is older than $MIN_MACOS" "renderLab targets macOS 13 Ventura or newer"
fi

info "CPU: $(uname -m) ($(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown))"

metal=""
if [ "$quick" -eq 0 ]; then
    gpu_report="$(system_profiler SPDisplaysDataType 2>/dev/null)"
    gpu_names="$(printf '%s\n' "$gpu_report" | awk -F': ' '/Chipset Model/ {print $2}' | paste -sd ',' -)"
    metal="$(printf '%s\n' "$gpu_report" | awk -F': ' '/Metal (Support|Family)/ {print $2; exit}')"
    [ -n "$gpu_names" ] && info "GPU: $gpu_names"
fi

section "Toolchain"

developer_dir="$(xcode-select -p 2>/dev/null)"
if [ -n "$developer_dir" ]; then
    pass "Developer tools: $developer_dir"
else
    fail "No Xcode or Command Line Tools found" "xcode-select --install   (or install Xcode from the App Store)"
fi

if command -v swift >/dev/null 2>&1; then
    swift_version="$(swift --version 2>/dev/null | sed -n 's/.*Swift version \([0-9.]*\).*/\1/p' | head -n1)"
    if version_ge "${swift_version:-0}" "$MIN_SWIFT"; then
        pass "Swift $swift_version (>= $MIN_SWIFT)"
    else
        fail "Swift ${swift_version:-unknown} is older than $MIN_SWIFT" "Install Xcode 16+ or newer Command Line Tools"
    fi
else
    fail "swift not found" "xcode-select --install"
fi

case "$developer_dir" in
    *CommandLineTools*)
        if [ -d /Applications/Xcode.app ]; then
            warn "Command Line Tools are selected: 'swift test' may fail with \"no such module 'Testing'\"" \
                 "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   (or: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)"
        else
            warn "Command Line Tools only: 'swift test' may fail with \"no such module 'Testing'\"" \
                 "Install Xcode 16+ to run the unit tests"
        fi
        ;;
esac

if command -v git >/dev/null 2>&1; then
    pass "git $(git --version | awk '{print $3}')"
else
    fail "git not found" "xcode-select --install"
fi

section "Dependencies"

if [ -f ThirdParty/imgui/imgui.h ]; then
    imgui_version="$(sed -n 's/^#define IMGUI_VERSION[[:space:]]*"\(.*\)"/\1/p' ThirdParty/imgui/imgui.h)"
    pass "Dear ImGui submodule ($imgui_version)"
else
    fail "Dear ImGui submodule is missing" "git submodule update --init"
fi

section "OpenGL backend"

if [ -d /System/Library/Frameworks/OpenGL.framework ]; then
    pass "OpenGL.framework present (OpenGL 4.1 Core max on macOS)"
else
    fail "OpenGL.framework not found" "OpenGL ships with macOS; this system looks unusual"
fi

section "Metal backend"

# Only the framework is required: every Mac that runs macOS 13 has a Metal GPU. The system_profiler
# text is informational, because it can be missing (VMs, SSH sessions, new macOS wording).
if [ ! -d /System/Library/Frameworks/Metal.framework ]; then
    fail "Metal.framework not found" "Metal ships with macOS; this system looks unusual"
elif [ -n "$metal" ]; then
    pass "Metal.framework present, GPU support: $metal"
elif [ "$quick" -eq 1 ]; then
    pass "Metal.framework present (run ./scripts/doctor.sh for GPU details)"
else
    warn "Metal.framework present, but no Metal GPU support was reported" \
         "Check System Information > Graphics/Displays; ./run.sh opengl still works"
fi

section "Result"

if [ "$failures" -gt 0 ]; then
    printf "  ${RED}%d required check(s) failed.${RESET} Fix them before building.\n" "$failures"
    exit 1
fi

printf "  ${GREEN}Ready.${RESET} ./run.sh opengl|metal   (or: swift run RenderLab --backend opengl|metal)\n"
[ "$warnings" -gt 0 ] && printf "  ${YELLOW}%d warning(s)${RESET} above.\n" "$warnings"
exit 0
