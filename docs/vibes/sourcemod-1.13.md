# Upgrading to SourceMod 1.13

Upstream facts were checked on 2026-11-25, against SourceMod `a830fd1` and
SourcePawn `95b59aa`. [Trial results](#trial-results) come from building parts of
it by hand. The Bazel targets haven't been changed.

Recommendation: stay on 1.12 until 1.13 is stable, then go straight to SourcePawn
2. The version without it is a dead end upstream.

## ETA for stable

**No date has been announced.** 1.13 builds are still published as pre-releases.

Estimate: **first half of 2027 at the earliest**, with low confidence.

| Version | Stable     | Since previous |
| ------- | ---------- | -------------- |
| 1.10    | 2019-10    |                |
| 1.11    | 2022-07    | 33 months      |
| 1.12    | 2024-10    | 27 months      |
| 1.13    | 2027-01 to 2027-07, if the pattern holds | 27 to 33 months |

Reasons it could be later:

- SourcePawn 2 landed on 2026-08-30 and is still getting fixes.
- [KHook](#khook) is an open draft with conflicts. Upstream hasn't said whether
  1.13 waits for it, but its description targets 1.13.

## Changes in either version

- **All extensions must be rebuilt.** The minimum extension API goes from 8 to 9,
  so extensions built against 1.12 don't load.
- **The VM is no longer a separate library.** It links into `sourcemod.logic`, so
  drop `sourcepawn_vm_shared` from `sourcemod/server.bzl`, and
  `sourcepawn.vm` / `sourcepawn.jit.x86` from the packages.
- **`Address` is an `int64`** in plugins.
- **Newer dependencies:** SQLite, libmaxminddb, and amtl.
- **Bundled sources:** compare `sourcemod/sdk.BUILD.bazel` with the new
  `AMBuilder` files.

Metamod stays on 1.12 unless [KHook](#khook) merges. The two SourceMod build-date
patches still apply.

## Without SourcePawn 2

Pin the last commit before it and before C++20:

| Source     | Commit                                     |
| ---------- | ------------------------------------------ |
| SourceMod  | `f3f696f16e1bc7f8dedc534d3f4556b1820a5f89` |
| SourcePawn | `f2d11ff1a80ac891b7fb7ba81ad78646d9232c3e` |
| amtl       | `44e73d48620c6f880d4243fdeb51e8160b379a9b` |
| safetyhook | `8c6692c85a6c41f5d89f744da57b5ba43515b4ec` |

- Stays on C++17, with no new third-party dependency.
- `spcomp-source-date-epoch.patch` is still needed, and applies with an offset.
- Plugins stay on SourcePawn 1 bytecode, so `smx_version_test` is unaffected.
- Extensions built here should still load with SourcePawn 2, which keeps 9 as the
  minimum API version.
- Misses everything after it (54 commits so far) and gets no fixes.

Worth it only as a stepping stone, to land the changes above separately.

## With SourcePawn 2

Track `master`, then the stable branch once there is one.

- **C++20:** update `private/flags.bzl` and `sourcemod/sdk.BUILD.bazel`. Metamod
  stays on C++14, and extensions can stay on C++17.
- **mimalloc:** fetch and build the
  [AlliedModders fork](https://github.com/alliedmodders/mimalloc) for the VM.
- **VM sources:** V1 moves to `vm/legacy`, beside the new `vm/v2`. Both are built,
  with separate JIT sources, so existing `.smx` files can still run.
- **Memory limits:** 32-bit servers allocate plugin memory in the low 2GB of the
  address space, and 64-bit ones reserve 2GB. Windows uses `VirtualAlloc2`, so
  test under Wine, which `hiddensource-server` uses.
- **`spcomp-source-date-epoch.patch` goes away.** Upstream has the feature.
- **Plugins:** `spcomp` emits SourcePawn 2 bytecode, which 1.12 servers reject.
  `smx_version_test` needs to expect it.
- **`sourcemod_test`:** change the guard in `spcomp/float.inc` from
  `__sourcepawn2__` to `__sourcepawn_intrinsic_float`. Without this, no test
  compiles.

### Keeping SourcePawn 1 plugins

`master` also builds the old compiler, as `oldspcomp`, from `legacy-compiler/`.
Plugins can use it while the server runs the new VM. `spcomp_toolchain` already
lets a consumer choose the compiler, so this only needs a target for it, and
a second toolchain. It's the fallback if plugins break.

## KHook

[#2403](https://github.com/alliedmodders/sourcemod/pull/2403) replaces SourceHook
and CDetour in SourceMod with [KHook](https://github.com/Kenzzer/KHook), which is
already in Metamod `master` (2.0). If it merges into 1.13:

- **SourceMod and Metamod move together.** 1.13 requires Metamod 2.0, which
  rejects plugins built for 1.12. Overriding only one of `sourcemod.sdk()` and
  `sourcemod.metamod()` breaks.
- **Windows cross-compilation breaks.** KHook matches MSVC's thunks and returns -1
  for the 32-bit `clang-cl` ones that `metamod-clang-thiscall-thunk.patch`
  handles. The check is in `khook.hpp`, so every extension that hooks virtual
  functions needs the patched header.
- **Builds:** use KHook's sources and headers in place of SourceHook's, including
  in `//hl2sdk:<branch>`. `safetyhook` moves to Metamod, `CDetour` goes away,
  SourceMod gains `libaddrz`, and Metamod moves to C++17.
- **Extensions:** those using SourceHook must be ported. Those using CDetour load
  but don't compile. None in the neighboring repositories use either.
- **`sourcemod_cstrike`:** the draft has the `cstrike` extension commented out of
  its build.

Its main benefit, 64-bit DHooks, doesn't reach us unless presets add `dhooks`.

## Friction with this repository's design

- **One SourceMod version per build.** Repository names and pins are global, so a
  consumer can't build for 1.12 and 1.13 servers together. Addons need a branch or
  release for each, since extensions (1.12 to 1.13) and SourcePawn 2 plugins (1.13
  to 1.12) don't load across versions.
- **Overrides don't reach 1.13.** `sourcemod.sdk()` changes commits, but the file
  lists in `sdk.BUILD.bazel` match one version. Early testing needs a branch of
  this repository.
- **New pins.** mimalloc (and KHook and `libaddrz`) need attributes in
  `extensions.bzl`.
- **`sourcepawn_compiler` is one library** holding both the compiler and the VM.
  `sourcemod.logic` needs the VM alone, and `oldspcomp` needs a second compiler
  that shares the first one's symbol names, so it has to be split.
- **`spcomp` links the VM,** so mimalloc is needed on build hosts too.
- **Module pins spread.** Each addon pins this repository, but Bazel builds a
  server with one version of it. Every addon has to support 1.13 before the server
  can move.

## Trial results

Linux x86_64, with this repository's clang and Debian bullseye sysroot, using
C++20 unless noted:

| Check                                                   | Result                            |
| ------------------------------------------------------- | --------------------------------- |
| SourcePawn VM, `spcomp`, and `oldspcomp` sources        | Compile                           |
| `core/logic`                                            | Compiles                          |
| `smsdk_ext.cpp`, in C++14, C++17, and C++20             | Compiles                          |
| `spcomp` and `spshell`                                  | Link and run                      |
| 24 bundled plugins and 16 others, with `-E`             | Compile                           |
| `spshell_unit_test`, with the `float.inc` fix           | Passes                            |
| A failing assertion                                     | Exits non-zero                    |
| Compiling a plugin twice with `SOURCE_DATE_EPOCH`       | Identical                         |
| 1.12 `ep1` sources under `clang-cl` in C++20            | 110 of 111 compile                |

The `ep1` failure is a `const` error in `tier1/memstack.h`, while building HL2SDK's
own `tier1`, which can stay on its current standard.

Not tried: 1.13's per-engine core and extensions, 32-bit, native MSVC, running a
server, or Wine.

## Steps

1. Update the pins, and the sources in `sourcemod/sdk.BUILD.bazel`.
2. Split `sourcepawn_compiler`, remove the VM library, and build the VM into
   `sourcemod.logic`.
3. For SourcePawn 2: C++20, mimalloc, `oldspcomp`, and the `float.inc` guard.
4. Run `bazel test //...` on each platform, and the examples.
5. Boot a server for each branch. Build tests won't catch extension loading or VM
   memory problems.
6. Rebuild and test downstream repositories before updating their pins.
