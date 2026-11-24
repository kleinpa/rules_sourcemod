# SourcePawn Studio (`sourcepawn-lsp`) Integration Potential

## What SourcePawn Studio Actually Is

If you have never used it: **SourcePawn Studio** is the de facto modern IDE
extension for SourcePawn across VS Code / VSCodium, Neovim, and JetBrains IDEs,
powered by [`sourcepawn-lsp`](https://github.com/Sarrus1/sourcepawn-lsp) (a
standalone Language Server Protocol binary written in Rust).

Under the hood it works in two layers:

1. **Fast static analysis (Tree-sitter + custom analyzer)** — Parses `.sp` and
   `.inc` files in memory as you type to provide go-to-definition, hover
   docstrings, signature help, symbol rename, methodmap/enum-struct member
   completion, and `#include <...>` navigation.
2. **Compiler-backed diagnostics (`spcomp`)** — Invokes a real `spcomp` binary
   in a temp out-path on save to report exact compiler errors and tag/type
   warnings inline.

## How It Expects a Project to Be Configured

`sourcepawn-lsp` does **not** have a build-system protocol like Rust's
`rust-project.json` or C++'s `compile_commands.json` per translation unit.
Instead, it reads workspace-level settings (typically `.vscode/settings.json`,
or equivalent `initializationOptions` in Neovim/JetBrains):

```json
{
  "SourcePawnLanguageServer.compiler.path": "/abs/path/to/spcomp",
  "SourcePawnLanguageServer.includeDirectories": [
    "/abs/path/to/sourcemod/plugins/include",
    "/abs/path/to/my_repo/my_extension/include"
  ],
  "SourcePawnLanguageServer.compiler.arguments": ["-E"]
}
```

## Why Bazel Breaks It Out of the Box

In a traditional SourceMod setup, devs unpack a SourceMod zip into their home
folder and drop every third-party `.inc` into one `scripting/include/` folder.
In `rules_sourcemod`:

1. **No manual SourceMod install exists** — `spcomp` is compiled from source by
   Bazel and lives inside `bazel-bin/external/+sourcemod+sourcemod_sdk/spcomp[.exe]`
   (and doesn't exist at all until built once).
2. **Includes are hermetic and scattered** — Standard library `.inc` files live
   under Bazel's `output_base` (`external/+sourcemod+sourcemod_sdk/plugins/include`),
   `spshell.inc` lives in `external/.../spcomp`, and custom extension/library
   `.inc` files live in workspace packages or generated `bazel-bin/` directories.

Without bridging those paths, opening a `.sp` file in VS Code produces red
squiggles on line 1 (`cannot read from file: "sourcemod"`).

## Integration Design: `bazel run` LSP Config Refresher

Modeled on `hedron_compile_commands` for C++, `rules_sourcemod` can provide a
tiny aspect + executable rule (e.g. `sourcemod_lsp_config` in `//:defs.bzl`):

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_lsp_config")

sourcemod_lsp_config(
    name = "refresh_lsp",
    targets = ["//..."],  # optional; defaults to scanning workspace plugin/test targets
)
```

Running `bazel run //:refresh_lsp` would:

1. **Ensure `spcomp` and generated `.inc` inputs are built** — Because `spcomp`
   and target `.inc` files are data dependencies of the refresher action,
   `bazel run` materializes `spcomp` and any generated `.inc` files on disk
   automatically.
2. **Collect include roots via an aspect** — Walk `sourcemod_plugin` and
   `sourcemod_test` targets, collecting:
   - The toolchain's `stdlib_includes` directory (`.../plugins/include`).
   - Workspace-relative and `bazel-bin`-relative directories from `includes`
     (including `spshell.inc` when tests are present).
3. **Resolve stable absolute paths** — Query `bazel info output_base` /
   `execution_root` (from `BUILD_WORKSPACE_DIRECTORY` at `bazel run` time) so
   paths resolve cleanly on both Linux and Windows without relying on fragile
   `bazel-*` convenience symlinks.
4. **Non-destructively update `.vscode/settings.json`** (and optionally print a
   JSON snippet for Neovim `nvim-lspconfig` users) — Update only the
   `SourcePawnLanguageServer.*` keys while leaving all other user VS Code
   settings untouched.

## Limitations & Tradeoffs to Know Up Front

- **Workspace-wide include path (LSP limitation)**: Because `sourcepawn-lsp`
  takes one flat `includeDirectories` list per workspace rather than per-target
  flags, two targets in the same repo defining conflicting `foo.inc` headers
  cannot be disambiguated by the LSP (though `bazel build` remains strict).
- **Stale paths after `bazel clean --expunge`**: Wiping Bazel's cache removes
  the extracted `@sourcemod_sdk` tree until `bazel run //:refresh_lsp` (or a
  build) runs again.

## Verdict: Worth Building?

**High value, very low complexity (~120 lines of Starlark + a tiny Python or C++
JSON merger).** For SourcePawn developers used to VS Code + SourcePawn Studio,
`git clone <repo> && bazel run //:refresh_lsp` giving full autocomplete,
hover docs, go-to-definition into SourceMod 1.12's `.inc` stdlib, and on-save
`spcomp` diagnostics — without ever downloading a SourceMod zip — removes the
single biggest day-to-day friction of adopting Bazel for `.sp` development.
