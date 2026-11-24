# Standalone `examples/` Workspace

`//tests` runs inside the root module, so it cannot catch problems that only
affect consumers: labels that resolve in the wrong repository, missing
visibility, or missing `use_repo` entries.

An `examples/` directory with its own `MODULE.bazel`, using
`local_path_override(module_name = "rules_sourcemod", path = "..")`, would catch
these in CI and give addon authors a template to copy.

## Contents

| Package    | Shows                                                                                                                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `//shared` | `sourcemod_library` with `strip_include_prefix = "include"`, plus a `sourcemod_test`                                                                         |
| `//ext`    | `sourcemod_extension` with one native (`Example_Add`) and its `.inc` (`pawn_hdrs`, `pawn_strip_include_prefix`); a second target with `branch = "tf2"`, `autoload = True` |
| `//plugin` | `sourcemod_plugin` with `deps = ["//ext", "//shared"]`                                                                                                      |
| `//`       | Root `pkg_filegroup` and `pkg_zip` release archive (see [addon-packaging.md](addon-packaging.md)); optionally a server layer that adds `@rules_sourcemod//sourcemod:sourcemod_tf2` |

## Setup notes

- List `examples` in `.bazelignore` so the root module's `//...` skips it.
- Add a CI step that runs `bazel test //...` from `examples/`.
- Register `@rules_sourcemod//linux:all` in the example's `MODULE.bazel`. The root
  module registers it as a `dev_dependency`, so consumers do not inherit it.
