# rules_sourcemod

> **Work in progress.** Only tested with 64-bit Linux builds. Builds are not
> yet reproducible.

A toolkit for building the [SourceMod](https://www.sourcemod.net/) side of a
game server image — plugins, extensions, and the SourceMod runtime itself,
packaged to drop into a server directory. It contains four components:

- **Bazel rules for the SourcePawn language**, with `spcomp` built from source
  and registered as a real toolchain.
- **Macros for building C++ SourceMod extensions**, using the standard Bazel
  C++ toolchain.
- **Presets that build the SourceMod and Metamod addon layer** — every binary
  and data file that goes under `addons/`, compiled from source for one of
  four HL2SDK branches.

## Install

```starlark
bazel_dep(name = "rules_sourcemod", version = "1.0.0")
```

## Extensions and plugins

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_extension", "sourcemod_plugin")

sourcemod_extension(
    name = "my_extension",
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
    includes = ["."],
)

sourcemod_plugin(
    name = "my_plugin",
    src = "my_plugin.sp",
    includes = ["//my_extension:natives.inc"],
)
```

| Rule                  | Produces                           | Installs to                   |
| ---------------------- | ----------------------------------- | ------------------------------ |
| `sourcemod_extension` | `<name>.ext.so` / `<name>.ext.dll` | `addons/sourcemod/extensions` |
| `sourcemod_plugin`    | `<name>.smx`                       | `addons/sourcemod/plugins`    |

An extension's code can also live in a plain `cc_library` passed via `deps` —
useful when something else (tests, tools) needs it without going through the
shared-library link. It just needs `@sourcemod_sdk//:sourcemod_headers` for
the platform defines, `smsdk_config.h` in its `hdrs`, and `alwayslink` isn't
your problem — `sourcemod_extension` links `deps` that way so `SMEXT_LINK`
and native registrations survive being found by symbol at load time rather
than by reference:

```starlark
cc_library(
    name = "core",
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
    includes = ["."],
    deps = ["@sourcemod_sdk//:sourcemod_headers"],
)

sourcemod_extension(
    name = "my_extension",
    deps = [":core"],
)
```

Both rules report their install path via rules_pkg's `PackageFilesInfo`, so
they drop straight into a `pkg_tar`/`pkg_zip`:

```starlark
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "my_addon",
    srcs = [":my_extension", ":my_plugin"],
)
```

```console
$ bazel build --platforms=@rules_sourcemod//platforms:linux_x86_32 //:my_addon
```

The result is an `addons/sourcemod/...` tree that extracts straight into a
game server directory.

## Game servers

Five ready-made presets, each a complete SourceMod + Metamod build for one
HL2SDK branch, packaged as a `pkg_filegroup`:

| Preset               | Branch    | Game extension | Arch          |
| -------------------- | --------- | --------------- | ------------- |
| `sourcemod_cstrike`  | `css`     | yes (`extensions/cstrike`) | 64-bit |
| `sourcemod_tf2`      | `tf2`     | yes (`extensions/tf2`)     | 64-bit |
| `sourcemod_l4d2`     | `l4d2`    | no              | 32-bit only   |
| `sourcemod_sdk2013`  | `sdk2013` | no              | 32-bit only   |
| `sourcemod_ep1`      | `ep1`     | no              | 32-bit only, Windows only |

Bundled plugins and archive format are left to the caller:

```starlark
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "sourcemod_layer",
    srcs = [
        "@rules_sourcemod//sourcemod:sourcemod_cstrike",
        "@sourcemod_sdk//:plugin_basecommands",
    ],
    package_dir = "/opt/game/cstrike",
)
```

```console
$ bazel build --platforms=@rules_sourcemod//platforms:linux_x86_32 //:sourcemod_layer
```

Branch and game are separate axes: most branches get a full server (core,
logic, sdktools, sdkhooks, topmenus, bintools) with no extra per-game piece,
since upstream never shipped a dedicated extension for them. `sdk2013` isn't
one game's branch either — it's the generic Source SDK 2013 base a number of
independent mods build against, so `sourcemod_sdk2013` is named after the
branch rather than a game; every SDK2013 mod wants the same binaries, and a
consumer building one just points its own `pkg_tar`'s `package_dir` at that
mod's install path.

These five presets are the complete list — the macro behind them isn't
public API, since HL2SDK_BRANCHES (`hl2sdk/repositories.bzl`) is a closed
set and every branch in it already has a preset. Adding a branch is a dict
entry there plus a preset in `sourcemod/BUILD.bazel`, not new code.

`ep1` (the original, pre-Orange Box Source engine) is the one branch here
with no Linux wiring at all -- see that entry's comment in
`hl2sdk/repositories.bzl` for why -- so `sourcemod_ep1` only builds for
`windows_x86_32`.

Extensions don't need the HL2SDK at all unless they call engine APIs
(SourceHook, `edict_t`, netprops) — one that only talks to SourceMod's own
interfaces builds from `@sourcemod_sdk` alone. One that does needs a branch's
HL2SDK on its `deps`, requested the same way the presets above get theirs —
nothing is fetched until asked for:

```starlark
hl2sdk = use_extension("@rules_sourcemod//hl2sdk:repositories.bzl", "hl2sdk")
hl2sdk.branch(name = "css")
use_repo(hl2sdk, "hl2sdk_css", "metamod_source")
```

tier0/vstdlib are the one place the build consumes prebuilt binaries;
everything else, including tier1/mathlib, compiles from the fetched SDK
source.

## Windows

Windows is supported as both a build host and a target. Everything —
extensions, plugins, and full game servers — builds with MSVC, and the
artifacts take the filenames SourceMod's loader actually looks for on Windows
(`.dll` rather than `.so`, `sourcemod_mm.x64.dll` on a 64-bit target):

```console
$ bazel build --platforms=@rules_sourcemod//platforms:windows_x86_32 //:my_addon
```

Since srcds is predominantly 32-bit, `windows_x86_32` is the common case.
Bazel's MSVC autoconfiguration generates a complete 32-bit toolchain but
registers only the 64-bit one, so `windows_x86_32` fails toolchain resolution
out of the box. This module registers the generated toolchain itself
(`MODULE.bazel`), which is all that was missing — no toolchain is written here,
and nothing extra is needed beyond a Visual Studio install.

l4d2 and sdk2013 are 32-bit only; see Design below.

### Cross-compiling from Linux

A `windows_x86_32` build can also be produced on a Linux host, without a
Windows machine, via `clang-cl`/`lld-link`. `toolchains_llvm` has no Windows
target support out of the box (tracked upstream, all still open, as of this
writing: bazel-contrib/toolchains_llvm#395, #390, #642), so this module
patches it (`patches/toolchains_llvm-windows-i686.patch`, applied through
`MODULE.bazel`'s `single_version_override`) rather than waiting on it. The
patch adds an isolated Windows/clang-cl code path that leaves the existing
Unix/Darwin toolchain generation untouched; `windows/xwin_sysroot.bzl` fetches
the Windows SDK + MSVC CRT (via [xwin](https://github.com/Jake-Shadle/xwin))
the compiler needs. Both files document the bugs hit and worked around along
the way in more detail than fits here.

This toolchain is deliberately *not* registered by default — cross-compiling
this way pulls a full LLVM distribution and a Windows SDK/CRT sysroot under
Microsoft's own distribution terms (see `windows/xwin_sysroot.bzl`), neither
of which a plain `bazel build //...` should pay for unasked. Opt in per
build:

```console
$ bazel build --platforms=@rules_sourcemod//platforms:windows_x86_32 \
    --extra_toolchains=@llvm_toolchain_windows_x86_32//:cc-toolchain-x86_32-windows \
    //:my_addon
```

Verified end to end — including through this repo's own SDK headers, not
just a synthetic example — by building `//tests:test_ext` this way and
confirming the output is a real 32-bit PE DLL. Not yet verified: an
HL2SDK-backed extension (`tier0.lib`/`vstdlib.lib` linking) or a full game
server preset built this way; those pull in far more of the vendored SDKs'
own build assumptions and haven't been exercised against this toolchain.

## Design

- **Pinned by commit SHA**, not a moving branch — SourceMod, SourcePawn,
  amtl, HL2SDK, Metamod. Pins live at the top of `sourcemod/repositories.bzl`
  and `hl2sdk/repositories.bzl`.
- **Target architecture is a platform, not a `-m32` flag** —
  `@rules_sourcemod//platforms:linux_x86_32`/`linux_x86_64`/`windows_x86_32`/
  `windows_x86_64`. l4d2 and sdk2013 are old enough that their vendored SDKs
  have no 64-bit build at all (l4d2's tier1 carries 32-bit-only inline asm),
  so those two only build 32-bit — their presets are marked incompatible with
  a 64-bit target platform, so a wildcard 64-bit build skips them instead of
  failing inside the SDK.
- **spcomp is built from source** and registered as a real toolchain, not
  invoked by path — see `spcomp/sources.bzl`.

## Reproducibility

Every input is pinned and fetched by Bazel; nothing depends on a system
SourceMod/Python/AMBuild install. Not yet hermetic in three ways:

- The C++ toolchain is the host's — the autoconfigured MSVC install on
  Windows, the system compiler on Linux. On Linux that also makes artifacts
  link against the build machine's glibc rather than the target's, a
  correctness issue on an older target and not just a reproducibility one.
  Needs a pinned-sysroot toolchain (`toolchains_llvm`); until then, build on a
  host no newer than the target.
- spcomp stamps a build timestamp into every plugin (`__DATE__`/`__TIME__` in
  `plugins/include/core.inc`).
- `__DATE__` in `sourcemm_api.cpp`/`metamod.h` gives day-granularity
  nondeterminism (`SOURCE_DATE_EPOCH` isn't set).

Packaging itself (rules_pkg) is deterministic.

## Testing

```console
$ bazel test //...
```

`//tests:cross_platform_tests` and the four game-server build tests
(`//tests:game_server_tests`) are tagged `manual` — the former needs a
registered 32-bit *Linux* toolchain (Bazel's Unix autoconfiguration emits one
for the host CPU only, so `g++-multilib` alone does not make
`//platforms:linux_x86_32` resolvable), the latter a multi-hundred-MB fetch per
branch. The Windows counterpart of that suffix test is not manual: it resolves
against the 32-bit MSVC toolchain this module registers, and is skipped by
`target_compatible_with` on non-Windows hosts.

```console
$ bazel test //tests:game_server_tests
```

## Upgrading SourceMod

1. Pick a tag from [alliedmodders/sourcemod](https://github.com/alliedmodders/sourcemod/tags).
2. Read the submodule SHAs it records: `git ls-tree <tag> public/amtl sourcepawn`
3. Update the pins at the top of `sourcemod/repositories.bzl`.
4. Diff the compiler's source lists against upstream's AMBuilder files
   (`compiler/`, `libsmx/`, `vm/`) and update `spcomp/sources.bzl` if files
   were added or removed.
5. `bazel test //...`
