# Design

How `rules_sourcemod` works, and the details [`README.md`](../README.md) leaves
out. For runnable workspaces, see [`examples/`](../examples/README.md).

- [Overview](#overview)
- [SourcePawn rules](#sourcepawn-rules)
- [Extensions](#extensions)
- [Packaging](#packaging)
- [Game-server presets](#game-server-presets)
- [Toolchains](#toolchains)
- [Upstream sources](#upstream-sources)
- [Reproducibility](#reproducibility)
- [Testing](#testing)

## Overview

A SourceMod build mixes two kinds of outputs with different platform rules:

- **SourcePawn plugins (`.smx`)** are platform-independent bytecode. `spcomp` is
  built from source for the **host** machine and compiles plugins once, whatever
  OS or CPU the server runs on.
- **C++ binaries (`.so` / `.dll`)**—extensions, SourceMod, and Metamod:Source—are
  built for the **target** platform selected with `--platforms` (or transitioned
  to with `platform_transition_pkg`).

Every rule that produces server files also attaches
[`rules_pkg`](https://github.com/bazelbuild/rules_pkg) install paths relative to
the game's mod directory (`cstrike/`, `tf/`, `dod/`, and so on), so plugins,
extensions, and full server presets drop straight into `pkg_tar` or `pkg_zip`
without manual path mapping.

## SourcePawn rules

### How includes and sources resolve

`sourcemod_library` and `sourcemod_extension` (when `pawn_hdrs` is set) return
`SourcePawnInfo`, which carries `.inc` headers, companion `.sp` files, and `-i`
search directories transitively through `deps`.

When `sourcemod_plugin` runs `spcomp`, search directories are passed in this
order:

1. Transitive `deps` (in topological preorder)
2. Targets listed in `includes`
3. SourceMod's bundled `plugins/include/` directory (`<sourcemod>`, `<sdktools>`,
   and the rest of the standard library)

Putting `deps` and `includes` ahead of the standard library lets a target
intentionally shadow a built-in header—which is also how `sourcemod_test`
replaces `<float>` (see [Unit testing](#unit-testing)).

In `sourcemod_library`:

- Put public headers meant for `#include <name>` in `hdrs`, and set
  `strip_include_prefix` when they live under a subdirectory such as `include/`.
  A leading `/` makes the prefix relative to the repository root; otherwise it
  is relative to the `BUILD.bazel` package.
- Put implementation files pulled in by relative path (such as
  `#include "detail/helpers.sp"`) in `srcs` so they are present in the compile
  sandbox without adding new `-i` directories.

### `sourcemod_plugin` attributes

| Attribute     | Meaning                                                                                                  |
| ------------- | -------------------------------------------------------------------------------------------------------- |
| `src`         | Entry `.sp` file passed to `spcomp`                                                                      |
| `plugin_name` | Output `.smx` stem when different from `name` (for example, `name = "plugin"`, `plugin_name = "my_mod"`) |
| `deps`        | `sourcemod_library` or `sourcemod_extension` targets providing `SourcePawnInfo`                          |
| `extra_srcs`  | Additional `.sp` / `.inc` files included by relative path (`#include "sub/part.sp"`)                     |
| `includes`    | File targets whose directories should be added to `-i` directly                                          |
| `defines`     | Preprocessor defines, as `"KEY"` (passed as `KEY=1`) or `"KEY=VAL"`                                      |
| `copts`       | Extra `spcomp` flags, such as `["-w234"]`                                                                |
| `werror`      | Pass `-E` to treat warnings as errors (`True` by default)                                                |

### Unit testing

`sourcemod_test` compiles a `.sp` file and runs its `public main()` inside
`spshell`, SourcePawn's standalone command-line VM. No game server or SourceMod
core is started, so game and SourceMod natives (`PrintToServer`, `CreateConVar`,
`SDKCall`, and similar) are unavailable—keep pure logic in a `sourcemod_library`
and test it there.

Float math (`+`, `-`, `*`, `/`, comparisons, `DegToRad`, `RadToDeg`) works out
of the box: `spcomp` implicitly injects `#tryinclude <float>` into every `.sp`
file, and `sourcemod_test` places `spcomp/float.inc` ahead of SourceMod's
standard library so float operators bind to `spshell`'s built-in VM natives
rather than SourceMod's `smn_float`.

Include `<spshell>` in tests for output and assertions. Any failed assertion or
unhandled VM exception prints a line-numbered stack trace and fails the test:

| Helper                              | Behavior                                    |
| ----------------------------------- | ------------------------------------------- |
| `assert_eq(actual, expected)`       | Fails if two cell values differ             |
| `assert_true(cond, message = ...)`  | Fails with `message` if `cond` is false     |
| `assert_false(cond, message = ...)` | Fails with `message` if `cond` is true      |
| `assert_streq(actual, expected)`    | Fails if two null-terminated strings differ |
| `print(str)` / `printf(fmt, ...)`   | Writes to test stdout                       |

`sourcemod_test` accepts the same `deps`, `includes`, `extra_srcs`, `defines`,
`copts`, and `werror` attributes as `sourcemod_plugin`, plus standard Bazel test
attributes (`size`, `timeout`, `tags`, `flaky`).

## Extensions

`sourcemod_extension` builds a SourceMod C++ extension shared library. Do **not**
list `smsdk_ext.cpp` in `srcs`: the rule compiles SourceMod's
`public/smsdk_ext.cpp` automatically and links with hidden default symbol
visibility so only `GetSMExtAPI` (and `CreateInterface_MMS` when
`SMEXT_CONF_METAMOD` is enabled) is exported.

Extensions come in two forms:

- **Engine-independent** (no `branch`): uses only SourceMod's own `IShareSys`
  interfaces and builds `<extension_name>.ext.<so|dll>`. One binary works across
  every Source 1 game on that OS and CPU.
- **Engine-specific** (`branch = "<branch>"`): links that branch's HL2SDK
  headers, `tier1`, `mathlib`, and Metamod:Source headers, restricts the target
  to platforms the branch supports, and names the output
  `<extension_name>.ext.<engine>.<so|dll>` (such as `my_ext.ext.2.tf2.so`).

| Attribute                   | Meaning                                                                                                                          |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `extension_name`            | Output name before `.ext` when different from `name`                                                                             |
| `branch`                    | HL2SDK branch (`"css"`, `"tf2"`, `"hl2dm"`, `"dods"`, `"l4d2"`, `"sdk2013"`, `"ep1"`)                                            |
| `game_server_hdrs`          | Also add the branch's `game/server` headers (`baseentity.h`, `variant_t.h`); requires `branch`                                   |
| `autoload`                  | Also generate `<extension_name>.autoload` so SourceMod loads the extension at startup without waiting for a plugin to request it |
| `pawn_hdrs`                 | Companion `.inc` files exposed to `sourcemod_plugin` via `SourcePawnInfo`                                                        |
| `pawn_strip_include_prefix` | Prefix stripped from `pawn_hdrs` when computing `-i` include paths                                                               |

### Cross-platform plugins with `<name>_inc`

When `pawn_hdrs` is set, `sourcemod_extension` also declares a companion
`<name>_inc` `sourcemod_library` target with no platform constraints.

If a plugin and its extension are always built for the same compatible platform,
`deps = [":my_extension"]` is enough. If the extension is restricted to specific
platforms—for example `branch = "ep1"` (Windows-only) or `branch = "l4d2"`
(32-bit-only)—depend on `deps = [":my_extension_inc"]` so the `.smx` plugin can
still be built on any host.

### Helper `cc_library` targets

If you split extension C++ code into a separate `cc_library` in `deps`, set
`alwayslink = True` on that `cc_library` whenever its files register natives or
hooks through static initializers not referenced directly from `SDKExtension`.
Otherwise the linker drops the unreferenced object files from the archive.

### libcurl

`@rules_sourcemod//sourcemod:curl` provides a static HTTPS-capable `libcurl` for
use in extension `deps` (and backs the presets' `webternet.ext`, replacing
upstream's TLS-less curl 7.19):

- **Linux**: links BoringSSL and reads `/etc/ssl/certs/ca-certificates.crt` (so
  minimal container images must install `ca-certificates`).
- **Windows**: uses native Schannel and the OS certificate store with no external
  TLS library, and defines `WIN32_LEAN_AND_MEAN` so `<windows.h>` does not pull
  in `<winsock.h>` ahead of `<winsock2.h>`.

## Packaging

Install paths in `rules_sourcemod` are relative to the **mod directory**
(`cstrike/`, `tf/`, `hl2mp/`, `dod/`, `left4dead2/`):

| Target                    | Path inside mod directory                                                     |
| ------------------------- | ----------------------------------------------------------------------------- |
| `sourcemod_plugin`        | `addons/sourcemod/plugins/<plugin_name>.smx`                                  |
| `sourcemod_extension`     | `addons/sourcemod/extensions/<stem>.so` (`.dll`, `extensions/x64/` on 64-bit) |
| `autoload = True`         | `addons/sourcemod/extensions/<extension_name>.autoload`                       |
| `//sourcemod:sourcemod_*` | `addons/metamod/...`, `addons/sourcemod/...`, `cfg/sourcemod/...`             |

Two details worth knowing:

- `.autoload` files always go in `addons/sourcemod/extensions/`, never
  `extensions/x64/`, because SourceMod's `TryAutoload()` only scans the top-level
  `extensions/` directory even on 64-bit servers.
- `pawn_hdrs` (`.inc` files) are exposed only through `SourcePawnInfo` and are
  never copied into packages.

### Multi-part addons and companion files

When an addon combines plugins, extensions, and runtime files (gamedata,
configs, translations, or custom assets), expose a `pkg_filegroup` as the main
library target and keep `pkg_tar` / `pkg_zip` separate for standalone release
archives:

```starlark
load("@rules_pkg//pkg:mappings.bzl", "pkg_filegroup", "pkg_files", "strip_prefix")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_files(
    name = "gamedata",
    srcs = glob(["gamedata/*.txt"]),
    prefix = "addons/sourcemod/gamedata",
    strip_prefix = strip_prefix.from_pkg("gamedata"),
)

pkg_filegroup(
    name = "my_addon",
    srcs = [
        ":gamedata",
        ":my_extension",
        ":my_plugin",
    ],
    visibility = ["//visibility:public"],
)

# Standalone archive users extract into their mod directory.
pkg_tar(
    name = "my_addon_tar",
    srcs = [":my_addon"],
    extension = "tar.gz",
)
```

Downstream server images can then put `@my_addon` straight into their own
`pkg_tar` with `package_dir = "/opt/game/cstrike"`, preserving file modes and
avoiding nested tarballs.

`platform_transition_pkg` forwards `rules_pkg` providers across `--platforms`
transitions, so transitioned presets and extensions keep the same install paths
(see [`examples/cross/BUILD.bazel`](../examples/cross/BUILD.bazel)).

## Game-server presets

Each `//sourcemod:sourcemod_<game>` target is a `pkg_filegroup` containing a
complete Metamod:Source and SourceMod installation built from source for one
engine branch:

| Preset              | Branch    | Supported platforms             | Game extension     |
| ------------------- | --------- | ------------------------------- | ------------------ |
| `sourcemod_cstrike` | `css`     | Linux and Windows, 32- & 64-bit | `game.cstrike.ext` |
| `sourcemod_tf2`     | `tf2`     | Linux and Windows, 32- & 64-bit | `game.tf2.ext`     |
| `sourcemod_hl2dm`   | `hl2dm`   | Linux and Windows, 32- & 64-bit | none               |
| `sourcemod_dods`    | `dods`    | Linux and Windows, 32- & 64-bit | none               |
| `sourcemod_l4d2`    | `l4d2`    | Linux and Windows, 32-bit       | none               |
| `sourcemod_sdk2013` | `sdk2013` | Linux and Windows, 32-bit       | none               |
| `sourcemod_ep1`     | `ep1`     | Windows, 32-bit                 | none               |

### What is included (and what is opt-in)

Every preset ships:

- **Metamod:Source**: `addons/metamod.vdf` (or `metamod_x64.vdf` /
  `metamod_win64.vdf`), the `server.<so|dll>` loader shim, and the branch's
  `metamod.<engine>.<so|dll>` core.
- **SourceMod core**: `addons/metamod/sourcemod.vdf`, the
  `sourcemod_mm[.x64].<so|dll>` loader in `addons/sourcemod/bin/`, and
  `sourcemod.<engine>`, `sourcemod.logic`, and `sourcepawn.vm` (or
  `sourcepawn.jit.x86` on 32-bit) in `bin/` (`bin/x64/` on 64-bit), plus stock
  `configs/`, `gamedata/`, `translations/`, and `cfg/sourcemod/` (with
  `DisableAutoUpdate` set to `"yes"` in `core.cfg` and unbundled-plugin convars
  commented out in `sourcemod.cfg`).
- **Autoloaded extensions**: `sdktools`, `sdkhooks`, `topmenus`, `bintools`, and
  the branch's game extension (`game.cstrike` or `game.tf2`) if it has one.
- **On-demand extensions**: `clientprefs`, `dbi.sqlite`, `geoip`, `regex`, and
  `webternet` (loaded automatically when a plugin uses them).

Left out of presets on purpose:

- **Bundled SourcePawn plugins** (`adminmenu`, `basecommands`, `mapchooser`,
  `rockthevote`, and the rest in [`sourcemod/plugins.bzl`](../sourcemod/plugins.bzl)):
  each is its own `@rules_sourcemod//sourcemod:plugin_<name>` target so servers
  only ship the commands and voting plugins they want.
- **`dbi.mysql` and `dbi.pgsql`**: optional database drivers not built yet
  (`dbi.mysql` requires an external MySQL client library).
- **`updater`**: mutates `gamedata/` in place at runtime rather than keeping
  server images immutable.

### Sharing work across branches

Engine-independent binaries (`metamod_loader`, `loader`, `logic`,
`sourcepawn_vm`, `topmenus`, `bintools`, `clientprefs`, `dbi.sqlite`, `geoip`,
`regex`, `webternet`) are compiled once per OS/CPU in `@sourcemod_sdk` and
`@metamod_source` and reused across every preset. Only HL2SDK-coupled binaries
(`metamod.<engine>`, `sourcemod.<engine>`, `sdktools`, `sdkhooks`, and
`game.<game>`) are compiled per branch.

Every target in a preset carries its branch's `target_compatible_with`
constraints, so `bazel build //...` automatically skips presets (and avoids
downloading their HL2SDK archives) when `--platforms` cannot target them.

Bazel defaults to unoptimized `fastbuild` builds; pass `-c opt` when building
server images or release artifacts.

On Episode One (`sourcemod_ep1`), the Source 2006 engine resolves
`addons/metamod.vdf` relative to `hl2/` rather than the mod directory, so mods
other than `hl2` must stack an override layer setting `"file"` to
`"../<mod>/addons/metamod/bin/server"` (see
[`examples/cross/BUILD.bazel`](../examples/cross/BUILD.bazel)).

Left out of presets on purpose:

- **Bundled SourcePawn plugins** (`adminmenu`, `basecommands`, `mapchooser`,
  `rockthevote`, and the rest in [`sourcemod/plugins.bzl`](../sourcemod/plugins.bzl)):
  each is its own `@rules_sourcemod//sourcemod:plugin_<name>` target so servers
  only ship the commands and voting plugins they want.
- **`dbi.mysql` and `dbi.pgsql`**: optional database drivers not built yet
  (`dbi.mysql` requires an external MySQL client library).
- **`updater`**: mutates `gamedata/` in place at runtime rather than keeping
  server images immutable.

### Sharing work across branches

Engine-independent binaries (`metamod_loader`, `loader`, `logic`,
`sourcepawn_vm`, `topmenus`, `bintools`, `clientprefs`, `dbi.sqlite`, `geoip`,
`regex`, `webternet`) are compiled once per OS/CPU in `@sourcemod_sdk` and
`@metamod_source` and reused across every preset. Only HL2SDK-coupled binaries
(`metamod.<engine>`, `sourcemod.<engine>`, `sdktools`, `sdkhooks`, and
`game.<game>`) are compiled per branch.

Every target in a preset carries its branch's `target_compatible_with`
constraints, so `bazel build //...` automatically skips presets (and avoids
downloading their HL2SDK archives) when `--platforms` cannot target them.

Bazel defaults to unoptimized `fastbuild` builds; pass `-c opt` when building
server images or release artifacts.

On Episode One (`sourcemod_ep1`), the Source 2006 engine resolves
`addons/metamod.vdf` relative to `hl2/` rather than the mod directory, so mods
other than `hl2` must stack an override layer setting `"file"` to
`"../<mod>/addons/metamod/bin/server"` (see
[`examples/cross/BUILD.bazel`](../examples/cross/BUILD.bazel)).

## Toolchains

| Build host       | Target platform                     | Toolchain                                       | Extra setup                                                     |
| ---------------- | ----------------------------------- | ----------------------------------------------- | --------------------------------------------------------------- |
| Linux `x86_64`   | `linux_x86_64`, `linux_x86_32`      | Hermetic Clang + lld (`//linux:all`)            | `register_toolchains("@rules_sourcemod//linux:all")`            |
| Linux `x86_64`   | `linux_x86_64`                      | Host GCC or Clang (`@local_config_cc`)          | None (output inherits host glibc/libstdc++ floor)               |
| Linux `x86_64`   | `windows_x86_32`                    | `clang-cl` + `lld-link` + `xwin` sysroot        | `sourcemod.windows_cross_toolchain(...)` + `--extra_toolchains` |
| Windows `x86_64` | `windows_x86_64`, `windows_x86_32`  | Native MSVC (`cl.exe` / `link.exe`)             | Visual Studio Build Tools with x64 and x86 targets              |
| macOS / ARM64    | Host (SourcePawn plugins and tests) | Host C++17 compiler (builds `spcomp`/`spshell`) | None (`spshell` uses its bytecode interpreter)                  |

### Linux

`@rules_sourcemod//linux:all` registers hermetic Clang/lld toolchains for 64-bit
and 32-bit Linux backed by pinned LLVM binaries and Debian 11 (`bullseye`)
sysroots assembled from pinned `.deb` packages. Linked `.so` files require at
most `GLIBC_2.31` and `GLIBCXX_3.4.28`, so they load on Debian 11+, Ubuntu
20.04+, and Steam Runtime `sniper` regardless of how new the build machine is.

`rules_sourcemod` registers these toolchains as `dev_dependency = True` for its
own builds. Consumer modules opt in from `MODULE.bazel`:

```starlark
register_toolchains("@rules_sourcemod//linux:all")
```

LLVM and the Debian sysroots are fetched lazily—only when one of those
toolchains is actually selected. Without them, Bazel falls back to the host
compiler, which targets only the host CPU and binds against the host's glibc and
`libstdc++`.

### Windows

Native Windows builds use MSVC with static CRT linking (`/MT`, or `/MTd` in debug
builds) to match upstream AMBuild, avoiding a runtime dependency on a matching
`vcruntime140.dll` / `msvcp140.dll` install on the server.

Bazel's `@local_config_cc` detects MSVC's 32-bit cross compiler
(`cc-compiler-x64_x86_windows`) on 64-bit Windows hosts but only registers the
64-bit and ARM64 toolchains by default; `rules_sourcemod` registers the 32-bit
toolchain automatically so `--platforms=@rules_sourcemod//platforms:windows_x86_32`
works out of the box.

If an extension depends on third-party `cc_library` targets outside
`rules_sourcemod`, add this to `.bazelrc` so those libraries also compile with
`/MT` instead of Bazel's default `/MD`:

```text
build --features=static_link_msvcrt
```

### Windows from Linux (`clang-cl`)

64-bit Linux hosts can cross-compile 32-bit Windows targets with `clang-cl`,
`lld-link`, and a case-normalized Windows SDK + MSVC CRT sysroot downloaded via
[xwin](https://github.com/Jake-Shadle/xwin). Opting in accepts the
[Microsoft Windows SDK and MSVC CRT license terms](https://github.com/Jake-Shadle/xwin#license)
from the root `MODULE.bazel`:

```starlark
sourcemod = use_extension("@rules_sourcemod//:extensions.bzl", "sourcemod")
sourcemod.windows_cross_toolchain(accept_license = True)
use_repo(sourcemod, "llvm_toolchain_windows_x86_32")
```

Pass `--extra_toolchains` on commands (or under a `.bazelrc` config) rather than
registering it globally, so ordinary Linux builds never download the Windows SDK:

```console
$ bazel build \
    --platforms=@rules_sourcemod//platforms:windows_x86_32 \
    --extra_toolchains=@llvm_toolchain_windows_x86_32//:cc-toolchain-x86_32-windows \
    @rules_sourcemod//sourcemod:sourcemod_ep1
```

Scope of `clang-cl` cross-builds: engine-independent extensions,
`//sourcemod:curl`, `spcomp`, and `//sourcemod:sourcemod_ep1` build cleanly from
Linux. Orange Box HL2SDK branches (`css`, `tf2`, `hl2dm`, `dods`, `l4d2`,
`sdk2013`) use MSVC-specific inline assembly and `__m128` union layout in
`mathlib` and require native MSVC on Windows (`ep1` carries patches for those in
[`patches/`](../patches/README.md)).

## Upstream sources

All upstream C and C++ trees are fetched as pinned archives verified by SHA256:

| Upstream tree                           | Pinned in                                                     | Root-module override tag |
| --------------------------------------- | ------------------------------------------------------------- | ------------------------ |
| SourceMod, SourcePawn, amtl, safetyhook | [`sourcemod/repositories.bzl`](../sourcemod/repositories.bzl) | `sourcemod.sdk(...)`     |
| Metamod:Source and its `amtl`           | [`hl2sdk/repositories.bzl`](../hl2sdk/repositories.bzl)       | `sourcemod.metamod(...)` |
| HL2SDK (one repository per branch)      | [`hl2sdk/repositories.bzl`](../hl2sdk/repositories.bzl)       | `sourcemod.hl2sdk(...)`  |
| libcurl                                 | [`sourcemod/repositories.bzl`](../sourcemod/repositories.bzl) | none                     |

The only prebuilt HL2SDK binaries linked are `tier0` and `vstdlib` (Valve does
not release their source, and `srcds` supplies them at runtime) plus upstream's
prebuilt `libpcre` for `regex.ext`. `tier1` and `mathlib` are compiled from
source just as upstream's `SdkHelpers.ambuild` does.

### Overriding pinned commits

A root `MODULE.bazel` can test or pin different upstream commits without forking
`rules_sourcemod` (non-root modules cannot set these tags; see
[`extensions.bzl`](../extensions.bzl) for all attributes):

```starlark
sourcemod = use_extension("@rules_sourcemod//:extensions.bzl", "sourcemod")

sourcemod.sdk(
    sourcemod_commit = "<commit>",
    sourcemod_sha256 = "<sha256>",
    # Optional: sourcepawn_commit/sha256, amtl_commit/sha256, safetyhook_commit/sha256
)

sourcemod.metamod(
    commit = "<commit>",
    sha256 = "<sha256>",
    # Optional: amtl_commit, amtl_sha256
)

sourcemod.hl2sdk(
    branch = "tf2",  # repeatable once per branch
    commit = "<commit>",
    sha256 = "<sha256>",
)
```

### Upgrading SourceMod

1. Pick a commit on SourceMod's stable branch and inspect its submodule pointers:
   `git ls-tree <commit> public/amtl public/safetyhook sourcepawn`.
2. Update the commit SHAs and archive SHA256s in
   [`sourcemod/repositories.bzl`](../sourcemod/repositories.bzl).
3. Diff `sourcemod/sdk.BUILD.bazel` against upstream's `AMBuildScript` and
   `AMBuilder` files for added or removed source files, defines, or flags.
4. Run `bazel test //...` across target platforms and refresh any patch in
   [`patches/`](../patches/README.md) that no longer applies cleanly.

## Reproducibility

Builds produce identical outputs across machines and runs:

- **Pinned inputs**: every upstream archive, `.deb` sysroot package, and LLVM
  release is pinned by SHA256.
- **Fixed timestamps**: `spcomp` runs with `SOURCE_DATE_EPOCH=315532800`
  (`1980-01-01 00:00:00 UTC`), `//linux` Clang redacts `__DATE__`, `__TIME__`,
  and `__TIMESTAMP__`, and source patches pin Metamod and SourceMod version
  timestamps (since native MSVC ignores `-D__DATE__` and `SOURCE_DATE_EPOCH`).
  Every patch and the reason it exists is documented in
  [`patches/README.md`](../patches/README.md).
- **Hermetic Linux compiler & sysroot**: registering `@rules_sourcemod//linux:all`
  isolates builds from the host compiler, headers, and glibc.

## Testing

```console
$ bazel test //...
```

What `//tests/...` checks:

- **Unit & bytecode tests**: `spshell_unit_test` exercises `sourcemod_test` and
  `SourcePawnInfo` propagation; `plugin_emits_sp1_bytecode_test` checks `.smx`
  output headers; `builtin_plugins_build_test` compiles every bundled SourceMod
  plugin.
- **Package layout tests**: transition `test_ext` and `test_branched_ext` to
  Linux and Windows platforms and verify output suffixes (`.ext.so`,
  `.ext.2.tf2.dll`), `x64/` placement, and `.autoload` paths.
- **Symbol closure tests (`*_resolves_its_symbols_test`)**: verify on Linux that
  self-contained shared libraries (`loader`, `logic`, and engine-independent
  extensions) have no undefined dynamic symbols outside their `DT_NEEDED` set.
- **ABI floor test (`sourcemod_cstrike_glibc_floor_test`)**: inspects dynamic
  symbol versions across every `.so` in `sourcemod_cstrike` and `test_ext` and
  fails if anything requires newer than `GLIBC_2.31` or `GLIBCXX_3.4.28`.
- **Preset build tests (`sourcemod_<game>_builds_test`)**: build every preset
  compatible with the active `--platforms` and skip the rest cleanly.

The Windows layout transition tests are tagged `manual` so plain Linux hosts do
not need a Windows toolchain; run them on Windows natively or on Linux with
`--extra_toolchains=@llvm_toolchain_windows_x86_32//:cc-toolchain-x86_32-windows`.
32-bit Linux and 32-bit Windows are target-only platforms in CI (`bazel build
//sourcemod/... //spcomp/...`), since Bazel test runners execute on 64-bit hosts.
