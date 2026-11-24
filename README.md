# rules_sourcemod

Bazel rules for building [SourceMod](https://www.sourcemod.net/) plugins, C++
extensions, standalone SourcePawn unit tests, and complete SourceMod +
Metamod:Source game-server addon layers from pinned upstream source:

- **SourcePawn toolchain (`sourcemod_plugin`, `sourcemod_library`, `sourcemod_test`)** —
  compiles `.sp` plugins with `spcomp`, manages transitive `.inc` libraries, and
  runs headless `.sp` unit tests in `spshell` from the pinned SourceMod 1.12
  stable tree.
- **C++ extensions (`sourcemod_extension`)** — builds engine-independent or
  engine-specific (`.ext.<engine>`) `.so` / `.dll` modules using Bazel's C++
  toolchain.
- **Game-server presets (`//sourcemod:sourcemod_*`)** — compiles Metamod:Source
  and SourceMod from source for five HL2SDK branches (`css`, `tf2`, `l4d2`,
  `sdk2013`, `ep1`).

## Install

Add `rules_sourcemod` to `MODULE.bazel` with `git_override` pinned to a commit:

```starlark
bazel_dep(name = "rules_sourcemod", version = "1.0.0")
git_override(
    module_name = "rules_sourcemod",
    remote = "https://github.com/lanofdoom/rules_sourcemod.git",
    commit = "<commit-sha>",
)
```

## Extensions, plugins, libraries, and tests

```starlark
load(
    "@rules_sourcemod//:defs.bzl",
    "sourcemod_extension",
    "sourcemod_library",
    "sourcemod_plugin",
    "sourcemod_test",
)

sourcemod_extension(
    name = "my_extension",
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
    includes = ["."],
    pawn_hdrs = ["include/my_extension.inc"],
    pawn_strip_include_prefix = "include",
)

sourcemod_library(
    name = "shared_helpers",
    hdrs = ["include/helpers/math.inc"],
    strip_include_prefix = "include",
)

sourcemod_plugin(
    name = "my_plugin",
    src = "my_plugin.sp",
    defines = ["ENABLE_FEATURE"],
    deps = [
        ":my_extension",
        ":shared_helpers",
    ],
)

sourcemod_test(
    name = "my_plugin_test",
    src = "my_plugin_test.sp",
    deps = [":shared_helpers"],
)
```

| Rule                  | Produces                                    | Installs to                          |
| --------------------- | ------------------------------------------- | ------------------------------------ |
| `sourcemod_extension` | `<name>.ext[.<engine>].<so\|dll>`           | `addons/sourcemod/extensions[/x64]`  |
| `sourcemod_library`   | `SourcePawnInfo` (`.inc` / `.sp` depset)    | —                                    |
| `sourcemod_plugin`    | `<name>.smx`                                | `addons/sourcemod/plugins`           |
| `sourcemod_test`      | headless `spshell` test target              | —                                    |

`sourcemod_extension` and `sourcemod_plugin` return `rules_pkg`'s
`PackageFilesInfo`, so they drop directly into `pkg_tar` / `pkg_zip` (`pawn_hdrs`
are exposed only through `SourcePawnInfo` and never leak into packages):

```starlark
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "my_addon",
    srcs = [":my_extension", ":my_plugin"],
)
```

- **Compiler flags (`sourcemod_plugin`, `sourcemod_test`)**: Both rules accept
  `defines = ["KEY", "KEY=VAL"]`, `copts = [...]` (e.g. `["-w234"]`), and
  `werror = True` (set `False` to omit `-E`).
- **Headless tests (`sourcemod_test`)**: Compiles a `.sp` file with `<spshell>`
  on the include path (`assert_eq`, `assert_true`, `assert_false`,
  `assert_streq`, `print`, `printf`) and runs `public main()` in the standalone
  SourcePawn VM without `srcds`.
- **Engine-specific extensions**: Extensions that only use SourceMod's own
  interfaces need no HL2SDK dependency. Extensions coupled to an engine branch
  set `branch = "tf2"` (optionally with `extension_name = "my_ext"`,
  `game_server_hdrs = True`, and `autoload = True`), which wires
  `@hl2sdk_tf2//:hl2sdk`, applies platform compatibility constraints, and emits
  `<extension_name>.ext.2.tf2.<so|dll>` (plus `<extension_name>.autoload` when
  requested). When `pawn_hdrs` is set, an unconstrained `:<name>.inc`
  `sourcemod_library` target is also generated.
- **`alwayslink` note**: If extension implementation code lives in a separate
  `cc_library` passed via `deps`, mark that `cc_library` `alwayslink = True` if
  any translation units register natives solely through static initializers.
- **Production optimization (`-c opt`)**: Bazel defaults to `fastbuild` (`-O0` /
  `/Od`). Pass `-c opt` when building server presets or extensions for
  production deployments so `sourcepawn.vm`, SQLite, Zydis, and C++ hooks are
  compiled with release optimizations.
- **Multi-platform packaging**: Wrap targets transitioning to another platform
  with `platform_transition_pkg` from `@rules_sourcemod//:defs.bzl` so
  `PackageFilesInfo` and `PackageFilegroupInfo` survive the transition.

## Game servers

Each preset in `//sourcemod:BUILD.bazel` is a `pkg_filegroup` containing a
complete SourceMod + Metamod build for one HL2SDK branch:

| Preset              | Branch    | Game extension       | Tested targets                        |
| ------------------- | --------- | -------------------- | ------------------------------------- |
| `sourcemod_cstrike` | `css`     | `extensions/cstrike` | Linux & Windows, 32-bit & 64-bit      |
| `sourcemod_tf2`     | `tf2`     | `extensions/tf2`     | Linux & Windows, 32-bit & 64-bit      |
| `sourcemod_l4d2`    | `l4d2`    | none                 | Linux & Windows 32-bit                |
| `sourcemod_sdk2013` | `sdk2013` | none                 | Linux & Windows 32-bit                |
| `sourcemod_ep1`     | `ep1`     | none                 | Windows 32-bit only                   |

32-bit Linux (`//platforms:linux_x86_32`) builds with the hermetic Linux
toolchain below (Bazel's own autoconfiguration only covers the host CPU). CI
builds it but cannot run 32-bit tests.

Each preset includes `sdktools`, `sdkhooks`, `topmenus`, `bintools`,
`clientprefs`, `dbi.sqlite`, `geoip`, and `regex` (plus the branch's game
extension where listed); engine-independent binaries are compiled once per
target platform and shared across presets. Database drivers that require
external client libraries (`dbi.mysql`, `dbi.pgsql`) are omitted.

Bundled SourcePawn plugins are opt-in per server deployment:

```starlark
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "sourcemod_layer",
    srcs = [
        "@rules_sourcemod//sourcemod:sourcemod_cstrike",
        "@rules_sourcemod//sourcemod:plugin_basecommands",
        "@rules_sourcemod//sourcemod:plugin_nextmap",
    ],
    package_dir = "/opt/game/cstrike",
)
```

`tier0` and `vstdlib` are the only prebuilt libraries consumed from the HL2SDK;
`tier1` and `mathlib` compile from the pinned SDK source.

## Linux

`//linux` provides hermetic clang/lld toolchains (LLVM 23, the same release as
the Windows cross toolchain) against Debian bullseye sysroots assembled from
pinned `.deb`s (`//linux:sysroot.bzl`). Built binaries need at most glibc 2.31 and
`GLIBCXX_3.4.28`, so they load on Debian 11 / Ubuntu 20.04 / Steam Runtime
sniper or newer regardless of the build host, and `linux_x86_32` gets a
toolchain at all. This module uses them for its own builds; opt in from yours
with:

```starlark
register_toolchains("@rules_sourcemod//linux:all")
```

LLVM and the sysroots are fetched only when a Linux target actually selects one
of these toolchains. `//tests:sourcemod_cstrike_glibc_floor_test` fails if a
shipped `.so` references newer symbol versions.

## Windows

Native Windows builds use MSVC (`//platforms:windows_x86_32` and
`//platforms:windows_x86_64`), statically linking the C/C++ runtime (`/MT`) to
match upstream AMBuild. This module registers the 32-bit MSVC toolchain Bazel
autoconfigures in `@local_config_cc`.

### Cross-compiling from Linux

`windows_x86_32` targets can also be cross-compiled on Linux x86_64 via
`clang-cl` / `lld-link` and a normalized [xwin](https://github.com/Jake-Shadle/xwin)
Windows SDK + MSVC CRT sysroot (`//windows:toolchain.bzl` and
`//windows:xwin_sysroot.bzl`). Opt in via the `sourcemod` module extension in
your root `MODULE.bazel`:

```starlark
sourcemod = use_extension("@rules_sourcemod//:extensions.bzl", "sourcemod")
sourcemod.windows_cross_toolchain(accept_license = True)
use_repo(sourcemod, "llvm_toolchain_windows_x86_32")
```

Then select the cross-toolchain per build so plain Linux builds do not download
LLVM or the Windows SDK unasked:

```console
$ bazel build --platforms=@rules_sourcemod//platforms:windows_x86_32 \
    --extra_toolchains=@llvm_toolchain_windows_x86_32//:cc-toolchain-x86_32-windows \
    //sourcemod:sourcemod_ep1
```

## Reproducibility

- All upstream trees (SourceMod, SourcePawn, amtl, safetyhook, Metamod, HL2SDK)
  are pinned by commit SHA and SHA256 checksum in `sourcemod/repositories.bzl`
  and `hl2sdk/repositories.bzl` (overridable from a root module via
  `sourcemod.sdk(...)` and `sourcemod.metamod(...)` in `extensions.bzl`).
- Build timestamps are pinned to `1980-01-01 00:00:00 UTC` via patches in
  `patches/` and `SOURCE_DATE_EPOCH` in `spcomp/plugin.bzl`.
- On Linux, registering `@rules_sourcemod//linux:all` replaces the host
  compiler and glibc with pinned LLVM + Debian bullseye (see [Linux](#linux));
  without it, build on a host whose glibc/libstdc++ is no newer than the target
  runtime image.

## Testing

```console
$ bazel test //...
```

Game-server presets are skipped on platforms their branch cannot target, so
`//...` builds every preset the selected `--platforms` supports.

## Upgrading SourceMod

1. Pick a commit from SourceMod's stable branch and read its
   submodule SHAs (`git ls-tree <commit> public/amtl public/safetyhook sourcepawn`).
2. Update the commit SHAs and SHA256s in `sourcemod/repositories.bzl`.
3. Diff `sourcemod/sdk.BUILD.bazel` against upstream's `AMBuildScript` /
   `AMBuilder` files for added or removed sources or flags.
4. Run `bazel test //...` (per target platform); regenerate any patch in
   `patches/` that no longer applies cleanly.
