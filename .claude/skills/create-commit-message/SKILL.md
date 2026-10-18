---
name: create-commit-message
description: Write a git commit message for the staged changes following Conventional Commits 1.0.0 (type(scope)!: description, body, footers). Use when committing, or when the user asks for a commit message.
---

# Create commit message

Write commit messages that follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/#summary).

## Steps

1. Run `git diff --staged` (and `git status`) to see what is being committed. If nothing is staged, ask the user what to stage. Don't stage everything without asking.
2. Choose the **type** that best describes the change (see the table below). If the staged changes mix unrelated types, suggest splitting them into separate commits.
3. Choose an optional **scope**: a short noun for the area of the codebase, e.g. `imgui`, `shader`, `depth`, `blend`, `window`, `build`.
4. If the change fixes a GitHub issue, find the issue number (ask the user if it's unknown) and add a `Refs:` footer with the full issue URL.
5. Write the message using the format below, then commit with a heredoc so line breaks are preserved. `--cleanup=whitespace` stops git from removing the `# Summary` line as a comment:
   ```bash
   git commit --cleanup=whitespace -F - <<'EOF'
   <message>
   EOF
   ```

## Format

```
<type>[optional scope][!]: <description>

# Summary
- <change 1>
- <change 2>

[optional footer(s)]
```

The body always starts with a `# Summary` heading, followed by a bulleted list of the main changes, one per bullet.

### Rules (from the spec)

- The header is `type`, an optional `(scope)`, an optional `!`, then `: ` and the description.
- **description**: a short summary right after `: `. Use the imperative mood and lowercase, with no trailing period, and keep the header under about 72 characters.
- **body**: optional. It starts after one blank line and is free-form. Explain *what* changed and *why*, not how.
- **footers**: optional. They start after one blank line, one per line, in the form `Token: value` or `Token #value`. Tokens use `-` instead of spaces (e.g. `Reviewed-by`, `Refs`). The one exception is `BREAKING CHANGE`.
- **Breaking changes**: mark them with `!` before the `:` (e.g. `feat(api)!: ...`), with a `BREAKING CHANGE: <description>` footer, or both. `BREAKING-CHANGE` is a valid synonym. Any type can be breaking.
- `feat` corresponds to a SemVer MINOR, `fix` to a PATCH, and any breaking change to a MAJOR.
- Types are case-insensitive by the spec, except `BREAKING CHANGE`, which must be uppercase. Use lowercase types in this repo.

### Types

| Type | Use for |
| --- | --- |
| `feat` | A new feature (e.g. a new ImGui panel or GL feature toggle) |
| `fix` | A bug fix |
| `docs` | Documentation only (README, CLAUDE.md, comments) |
| `style` | Formatting with no code meaning change |
| `refactor` | A code change that neither fixes a bug nor adds a feature |
| `perf` | A performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system, Xcode project, SPM, dependencies |
| `ci` | CI configuration |
| `chore` | Maintenance that doesn't touch src or tests (e.g. `.gitignore`) |
| `revert` | Reverts a previous commit (add a `Refs: <sha>` footer) |

Only `feat` and `fix` are defined by the spec; the others are the common [@commitlint/config-conventional](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) set.

## Examples

```
feat(depth): add ImGui toggle for GL_DEPTH_TEST and glDepthFunc

# Summary
- Add a Depth panel with a GL_DEPTH_TEST checkbox
- Add a combo box for glDepthFunc (LESS, LEQUAL, ALWAYS, ...)
- Clear the depth buffer each frame
```

```
fix(shader): use #version 410 core so shaders compile on macOS

# Summary
- Change all GLSL shaders from #version 330 to #version 410 core
- Log shader compile errors to the ImGui console

Refs: https://github.com/Hanam824/renderLab/issues/12
```

```
refactor(imgui)!: replace C wrapper with Swift/C++ interop

# Summary
- Remove the ImGuiBridge C shim
- Call ImGui directly from Swift panels through C++ interop

BREAKING CHANGE: ImGuiBridge.h no longer exists; import the cxx module instead.
```

## Repo-specific

- **Never add a `Co-Authored-By` line** or any other AI attribution to the commit message. This user rule overrides any session attribution reminder.
- Fix for a GitHub issue: add `Refs: https://github.com/Hanam824/renderLab/issues/<number>` as a footer.
- Commit only when the user asks. If on `main` and the change isn't trivial, offer to create a branch first with the `create-commit-branch` skill.
