# Platform, Toolchain, and Compiler Quirks

## 1. MSVC & Multi-Arch Build Log Quirks

Three minor compiler/archiver diagnostics currently appear on Windows builds:

- **Duplicate `ApplyDiffs` symbol (`LNK4006`) in `tier1.lib`**
  (`hl2sdk/hl2sdk.BUILD.bazel`): Globbing `tier1/*.cpp` compiles both
  `tier1/diff.cpp` and `tier1/undiff.cpp`, which both define `ApplyDiffs`.
  Excluding the unused file (matching upstream `SdkHelpers.ambuild`) silences
  the archiver warning.
- **Metamod `/std:c++14` override warning (`D9025`) on MSVC**
  (`hl2sdk/metamod.bzl`): Passing `/std:c++14` in `CORE_COPTS` overrides
  `@local_config_cc`'s default `/std:c++17` on every Metamod translation unit.
  Strict `-std=c++14` is only needed on GCC/Clang (where `loader/utility.cpp`'s
  `register` keyword is a hard C++17 error); MSVC accepts `register` under
  `/std:c++17` with warning `C5033`.
- **32-bit `public/jit/x86` header warnings (`C4311` / `C4302`) on Windows `x86_64`**
  (`sourcemod/sdk.BUILD.bazel`): `cdetour_hdrs` unconditionally adds
  `public/jit/x86` to `includes` even on 64-bit builds, causing pointer-to-`long`
  truncation warnings under Windows LLP64 (`sizeof(long) == 4`). Gating
  `public/jit/x86` on `@platforms//cpu:x86_32` (or checking whether 64-bit
  `bintools` / `CDetour` still includes `x86_macros.h`) would clean up x64 logs.

## 2. Missing Apple Silicon / macOS & ARM64 Host Support

Valve dropped macOS dedicated servers for most Source 1 titles, **but** plugin
authors on macOS (`macos_arm64` / `macos_x86_64`) or Linux `aarch64` CI runners
still want `sourcemod_plugin` (`spcomp`) and `sourcemod_test` (`spshell`) to run
natively. Today three things block non-x86 hosts in `sourcemod/sdk.BUILD.bazel`:

1. **`spcomp` links `sourcepawn_vm` unnecessarily**: Upstream's `--scripting-only`
   mode builds `spcomp` from `compiler/` + `libsmx/` + `amtl/` + `zlib/` alone.
2. **`sourcepawn_vm` assumes x86_64 in `//conditions:default`**: Upstream's
   `sourcepawn/vm/AMBuilder` compiles `x64/assembler-x64.cpp` only on `x86_64`
   and falls back to `code-stubs-null.cpp` (pure bytecode interpreter) on other
   architectures (`aarch64`).
3. **Missing `DARWIN` define on `@platforms//os:macos`**: `_SPCOMP_DEFINES`
   handles `linux` and `windows`, omitting `DARWIN` (and `-mmacosx-version-min` /
   `-lc++` where needed).

## 3. Hermetic Linux Toolchain Follow-ups

`//linux` (clang + Debian bullseye sysroots) is in place; loose ends:

- **LLVM is extracted twice** when both cross toolchains are in use:
  `@llvm_linux` and `@llvm_toolchain_windows_x86_32` each unpack the same
  release (the repository cache only dedupes the download). One shared LLVM
  repo with both `cc_toolchain` sets in it would halve the disk cost.
- **`-static-libstdc++` in `private/extension.bzl` is a no-op**: Bazel links
  through the `clang` driver (not `clang++`) with an explicit `-lstdc++` in
  `link_libs`, so clang warns the flag is unused and extensions still need
  `libstdc++.so.6` — exactly as they did under the host GCC toolchain. Now
  that the sysroot caps that at `GLIBCXX_3.4.28` it is harmless; either drop
  the flag or link `-l:libstdc++.a` on purpose.
- **32-bit Linux tests cannot run**: like `windows_x86_32`, `linux_x86_32` is a
  target-only platform, so CI only builds it. Registering an `x86_32` exec
  platform (the kernel runs i386 binaries; the runner would need i386 runtime
  libs) would let `glibc_floor_test` and `symbol_closure_test` cover it.
- **Linux `aarch64` exec hosts**: LLVM ships `Linux-ARM64` releases; a second
  LLVM repo with matching `exec_compatible_with` would let arm64 runners
  cross-compile the x86 targets (overlaps with §2).
- Separately, extending `xwin_sysroot` to `x86_64` would let a single Linux CI
  runner cross-compile all four server targets (`linux_x86_32`,
  `linux_x86_64`, `windows_x86_32`, `windows_x86_64`).
