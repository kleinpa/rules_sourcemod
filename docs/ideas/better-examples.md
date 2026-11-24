# Standalone `examples/` Consumer Workspace

## Motivation

All targets in `//tests` run inside the `rules_sourcemod` root module itself. A
self-contained `examples/` directory with its own `MODULE.bazel` (wired via
`local_path_override(module_name = "rules_sourcemod", path = "..")`) serves two
purposes at once:

1. **Copy-pasteable starter template** for SourcePawn plugin and C++ extension
   authors evaluating `rules_sourcemod`.
2. **Consumer repo-mapping test in CI** — catches subtle Bzlmod bugs (unwrapped
   `Label(...)` strings in macros, private visibility leaks, missing `use_repo`
   exports) that pass inside the root module but fail in downstream repos.

## What `examples/` Should Show

Keep it small (~3 packages, fast to build in CI):

1. **`//shared`** (`sourcemod_library`):
   - Demonstrates `strip_include_prefix = "include"`, subdirectory `#include`
     layout (`include/example/formatting.inc`), and a headless `sourcemod_test`
     unit test (`bazel test //shared:formatting_test`).
2. **`//ext`** (`sourcemod_extension`):
   - Minimal C++ extension registering one native (`Example_Add`), exporting its
     companion `include/example_ext.inc` via `pawn_hdrs` +
     `pawn_strip_include_prefix = "include"`.
   - Plus a second engine-specific target (`branch = "tf2"`, `autoload = True`)
     showing HL2SDK linkage.
3. **`//plugin` & `//:release`** (`sourcemod_plugin` + `pkg_zip` / `pkg_tar`):
   - Compiles `example_plugin.sp` with `deps = ["//ext", "//shared"]`.
   - Packages `:release_zip` (`pkg_zip`) producing a ready-to-extract
     `addons/sourcemod/{extensions,plugins}/...` release archive matching what
     authors upload to GitHub Releases or AlliedModders forums.
   - Optionally shows a 10-line server layer (`pkg_tar` combining
     `@rules_sourcemod//sourcemod:sourcemod_tf2`, selected bundled plugins, and
     the custom addon).
