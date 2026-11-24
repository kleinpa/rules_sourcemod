# rules_sourcemod

Bazel rules for building [SourceMod](https://www.sourcemod.net/) plugins,
extensions, and game servers.

- Replaces AMBuild for SourceMod extensions and plugins
- Includes targets for SourceMod and Metamod:Source built from source
- Supports Linux and Windows and limited cross-compilation

This tooling was originally designed to help build clean game server
containers.

## Install

Add to `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_sourcemod")
git_override(
    module_name = "rules_sourcemod",
    remote = "https://github.com/lanofdoom/rules_sourcemod.git",
    commit = "<commit-sha>",
)
```

## Usage

See [`examples`](examples) for complete projects.

### `sourcemod_plugin`

Compiles a `.sp` file into a `.smx` plugin.

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_plugin")

sourcemod_plugin(
    name = "my_plugin",
    src = "my_plugin.sp",
)
```

### `sourcemod_library`

Shares `.inc` files between plugins. With the prefix stripped, this one is
included as `<helpers/math>`.

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_library", "sourcemod_plugin")

sourcemod_library(
    name = "helpers",
    hdrs = ["include/helpers/math.inc"],
    strip_include_prefix = "include",
)

sourcemod_plugin(
    name = "my_plugin",
    src = "my_plugin.sp",
    deps = [":helpers"],
)
```

### `sourcemod_extension`

Builds a C++ extension. List its `.inc` files in `pawn_hdrs` so plugins can
depend on it directly.

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_extension")

sourcemod_extension(
    name = "my_extension",
    srcs = ["src/extension.cpp"],
    hdrs = ["src/smsdk_config.h"],
    includes = ["src"],
    pawn_hdrs = ["my_extension.inc"],
)
```

If the extension uses the HL2SDK, set `branch` to one of the branches
[below](#game-servers).

### `sourcemod_test`

Runs a `.sp` file's `main()` without a game server. SourceMod and game natives
are not available.

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_test")

sourcemod_test(
    name = "math_test",
    src = "math_test.sp",
    deps = [":helpers"],
)
```

### Game servers

Presets contain SourceMod and Metamod:Source for one game. Package one with
[rules_pkg](https://github.com/bazelbuild/rules_pkg), along with your own
plugins and extensions and any of
[SourceMod's bundled plugins](sourcemod/plugins.bzl):

```starlark
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "server",
    srcs = [
        ":my_extension",
        ":my_plugin",
        "@rules_sourcemod//sourcemod:plugin_basecommands",
        "@rules_sourcemod//sourcemod:sourcemod_cstrike",
    ],
)
```

| Preset              | Branch    | Game                            |
| ------------------- | --------- | ------------------------------- |
| `sourcemod_cstrike` | `css`     | Counter-Strike: Source          |
| `sourcemod_tf2`     | `tf2`     | Team Fortress 2                 |
| `sourcemod_hl2dm`   | `hl2dm`   | Half-Life 2: Deathmatch         |
| `sourcemod_dods`    | `dods`    | Day of Defeat: Source           |
| `sourcemod_l4d2`    | `l4d2`    | Left 4 Dead 2                   |
| `sourcemod_sdk2013` | `sdk2013` | Source SDK 2013 mods            |
| `sourcemod_ep1`     | `ep1`     | Episode One mods (Windows only) |

### `platform_transition_pkg`

Builds a preset, plugin, or extension for another platform. Use the result in
`pkg_tar`. See [`platforms`](platforms/BUILD.bazel) for the available platforms.

```starlark
load("@rules_sourcemod//:defs.bzl", "platform_transition_pkg")

platform_transition_pkg(
    name = "server_linux32",
    src = "@rules_sourcemod//sourcemod:sourcemod_cstrike",
    target_platform = "@rules_sourcemod//platforms:linux_x86_32",
)
```

Some platforms need extra setup; see [docs/design.md](docs/design.md#toolchains).

## Targets

These are available to other repositories under `@rules_sourcemod`:

| Target                    | Contents                                                                             |
| ------------------------- | ------------------------------------------------------------------------------------ |
| `//sourcemod:sourcemod_*` | [Game-server presets](#game-servers)                                                 |
| `//sourcemod:plugin_*`    | [Bundled plugins](sourcemod/plugins.bzl)                                             |
| `//sourcemod:headers`     | SourceMod C++ headers                                                                |
| `//sourcemod:curl`        | libcurl, for use in extensions                                                       |
| `//hl2sdk:<branch>`       | HL2SDK and Metamod:Source headers for one branch, plus the HL2SDK libraries          |
| `//platforms:*`           | Target platforms: `linux_x86_32`, `linux_x86_64`, `windows_x86_32`, `windows_x86_64` |
| `//linux:all`             | Linux [toolchains](docs/design.md#toolchains)                                        |
