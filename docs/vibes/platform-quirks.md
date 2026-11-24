# Platforms and Toolchains

## Windows compiler warnings

- **`LNK4006`, duplicate `ApplyDiffs`** (`hl2sdk/hl2sdk.BUILD.bazel`).
  `tier1/diff.cpp` and `tier1/undiff.cpp` both define it. Exclude `undiff.cpp`,
  which defines nothing else. (Upstream compiles both.)
- **`D9025`, `/std:c++14` overrides `/std:c++17`** (`hl2sdk/metamod.bzl`).
  `rules_cc` already passes `/std:c++17`. Metamod needs C++14 only on GCC and
  Clang, where C++17 rejects the `register` in `loader/utility.cpp`; MSVC only
  warns (`C5033`). Remove `/std:c++14` from the MSVC flags.
- **`C4311` / `C4302`, pointer truncation on x64**. `public/jit/x86/x86_macros.h`
  casts pointers to `long`, which is 32-bit on Windows. The 64-bit `bintools`
  includes this header, so its include path cannot be limited to x86. Suppress the
  warnings on `bintools` instead.

## Cross toolchains

- **LLVM is extracted twice.** `@llvm_linux` and `@llvm_toolchain_windows_x86_32`
  each unpack the same release; the repository cache shares only the download. One
  LLVM repository holding both `cc_toolchain` sets would save the disk space.
- **No Windows x64 cross build.** Adding x86_64 to `xwin_sysroot` and
  `windows/toolchain.bzl` would let one Linux runner build all four server
  platforms.
- **32-bit Linux is built but not tested.** `linux_x86_32` is a target platform
  only. Registering an x86_32 execution platform, with i386 runtime libraries on
  the runner, would let `glibc_floor_test` and `symbol_closure_test` cover it.

## Non-x86 hosts

Plugin authors on Apple silicon or Linux arm64 need `sourcemod_plugin` and
`sourcemod_test` to run natively. Blockers:

1. **The VM build assumes x86.** `sourcepawn_vm` in `sourcemod/sdk.BUILD.bazel`
   selects the x64 sources on every CPU except x86_32. Upstream's build adds no
   architecture sources for arm64. The bytecode interpreter is portable C++, so
   `code-stubs-null.cpp`, which upstream uses for Emscripten, is the likely
   substitute. It does not support fake natives, and an arm64 build is untested.
2. **`spcomp` needs the VM.** It validates its output by loading it
   (`VerifyBinary` in `compiler/assembler.cpp`), so it cannot simply drop the
   dependency.
3. **macOS needs `DARWIN`.** Upstream defines it, and `compiler/main.cpp` and
   `compiler/lexer.cpp` check it, but `_SPCOMP_DEFINES` does not set it.

Separately, Linux arm64 hosts cannot cross-compile server binaries because
`@llvm_linux` downloads the x64 LLVM release. A second repository using the
`Linux-ARM64` release would fix that.
