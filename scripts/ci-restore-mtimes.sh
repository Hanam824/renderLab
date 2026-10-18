#!/usr/bin/env bash
# Set every tracked file's modification time to the time of the last commit that touched it,
# in the repo and in every submodule.
#
# CI checks out a fresh copy, so every file looks brand new and SwiftPM would recompile
# everything, even with a cached .build. With commit-based times, unchanged files keep the same
# timestamp from run to run and the cached build products stay valid.
set -euo pipefail

cd "$(dirname "$0")/.."

restore() {
    local repo="$1"
    # One `git log` walk: print each commit's time, then the files it touched; the first time a file
    # appears is its most recent change. perl sets all the times in one process (touch per file is slow).
    git -C "$repo" log --name-only --format='%ct' --no-renames HEAD | awk -v repo="$repo" '
        /^[0-9]+$/ { time = $0; next }
        NF && !seen[$0]++ { print time "\t" repo "/" $0 }
    ' | perl -ne 'chomp; my ($time, $path) = split /\t/, $_, 2; utime($time, $time, $path) if -f $path;'
}

restore .
git submodule foreach --quiet --recursive 'echo "$displaypath"' | while read -r submodule; do
    restore "$submodule"
done
