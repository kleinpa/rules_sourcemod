# Upstream SourceMod Build Parity

## Missing extensions

Extensions in upstream's `AMBuildScript` that `sourcemod/sdk.BUILD.bazel` does not
build:

| Extension | Output          | Needs                                                                       | Notes                                                                                              |
| --------- | --------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `dhooks`  | `dhooks.ext`    | `CDetour`, `safetyhook`; on x86, `sourcepawn/vm/x86/assembler-x86.cpp`      | Windows x86 / x64 and Linux x86; upstream skips Linux x64                                          |
| `updater` | `updater.ext`   | `webternet.ext` at runtime                                                  | Core loads it at startup to update `gamedata/` unless `DisableAutoUpdate` is `"yes"`. Make it opt-in; image contents should not change at runtime |
| `pgsql`   | `dbi.pgsql.ext` | In-tree prebuilt `libpq`; zlib on Linux                                     | Opt-in                                                                                             |
| `mysql`   | `dbi.mysql.ext` | External MySQL client library                                               | Opt-in; the only one needing a library that is not in the tree                                     |

## Linux symbol hiding

Upstream compiles everything with `-fvisibility=hidden` and
`-fvisibility-inlines-hidden`. Here, `private/extension.bzl` does, but
`SERVER_COPTS` (`private/flags.bzl`), `CORE_COPTS` (`hl2sdk/metamod.bzl`), and
`_SDK_LIB_COPTS` (`hl2sdk/hl2sdk.BUILD.bazel`) do not.

As a result, server libraries export their internals, including HL2SDK code such
as `CUtlBuffer` and `_VectorNormalize`, which can clash with the engine's own
copies inside `srcds`. Exported symbols in a Linux x86_64 build:

| Library                            | Symbols |
| ---------------------------------- | ------- |
| `sourcemod_cstrike` core           | 5,873   |
| `sourcemod.logic`                  | 5,688   |
| Metamod `css` core                 | 2,117   |
| A minimal `sourcemod_extension`    | 5       |

Fix: add both flags to all three lists, and `-Wl,--exclude-libs,ALL` to the server
and Metamod link options. Check the result with `nm -D --defined-only`;
`symbol_closure_test` only detects unresolved symbols.

## `libstdc++` linking

Upstream links `libstdc++` statically. `private/extension.bzl` passes
`-static-libstdc++`, but it has no effect: Bazel links with the C driver and an
explicit `-lstdc++`. Extensions, SourceMod libraries, and the Metamod cores all
need `libstdc++.so.6`.

The `//linux` toolchain limits that requirement to `GLIBCXX_3.4.28`, so this is
harmless on Debian 11 or newer. Either remove the flag, or link
`-l:libstdc++.a` everywhere to support servers with an older `libstdc++`.

## Optional

- **Windows version resources.** Upstream compiles `version.rc` into each binary
  (defining `BINARY_NAME` and `RC_COMPILE`), so file properties and minidumps show
  version information.
- **Crash symbols.** Upstream can generate Breakpad symbols for its binaries.
