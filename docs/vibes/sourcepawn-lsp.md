# SourcePawn Studio Integration

[SourcePawn Studio](https://github.com/Sarrus1/sourcepawn-studio) is a SourcePawn
language server with a VS Code / VSCodium extension; its binary also works with
other LSP clients such as Neovim. It provides completion, navigation, hover, and
rename, and on save runs `spcomp --syntax-only` for compiler diagnostics.

## Problem

The server does not understand build systems. It reads workspace-wide settings:

```json
{
  "SourcePawnLanguageServer.compiler.path": "/abs/path/to/spcomp",
  "SourcePawnLanguageServer.includeDirectories": [
    "/abs/path/to/sourcemod/plugins/include",
    "/abs/path/to/my_repo/my_extension/include"
  ]
}
```

The usual setup downloads a SourceMod release. With Bazel there isn't one:

- `spcomp` is built from source for the exec platform, under
  `bazel-out/<exec-config>/bin/external/<repo>/`, where `<repo>` is the
  canonical name of `sourcemod_sdk`.
- Standard includes are in `<output_base>/external/<repo>/plugins/include`.
- Other `.inc` files are in workspace packages, `bazel-out`, or external
  repositories.

## Proposed rule

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_lsp_config")

sourcemod_lsp_config(
    name = "refresh_lsp",
    targets = ["//plugin:my_plugin", "//plugin:my_plugin_test_smx"],
)
```

`bazel run //:refresh_lsp` would:

1. Build `spcomp` and any generated `.inc` files, as dependencies of the rule.
2. Collect include directories with an aspect that reads `deps` and `includes`.
   `sourcemod_plugin` does not return `SourcePawnInfo`, and `sourcemod_test` is a
   macro, so the aspect visits its `<name>_smx` target.
3. Convert paths to absolute using `bazel info output_base` and
   `bazel info execution_root`, run from `BUILD_WORKSPACE_DIRECTORY`.
4. Update only the two settings above in `.vscode/settings.json`, and optionally
   print the JSON for other editors.

Rule attributes cannot hold wildcards such as `//...`. Discovering targets
automatically would mean running `bazel query` from the tool, as
`hedron_compile_commands` does with `aquery`.

## Limitations

- **One include list per workspace.** Targets with conflicting header names cannot
  be told apart. This includes `<float>`: tests use `spcomp/float.inc` and plugins
  use SourceMod's. Listing the standard includes first resolves it for plugins.
- **Stale paths.** Rerun the target after `bazel clean`, after a SourceMod upgrade,
  or when include directories change.
