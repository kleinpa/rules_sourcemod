# Platforms and Toolchains

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
- **`clang-cl` Metamod loader (`addons/metamod/bin/server.dll`) crashes on a
  background thread under Wine.** On `ep1` (`windows_x86_32`), the cross-compiled
  Metamod core (`metamod.2.ep1.dll`), SourceMod (`sourcemod.2.ep1.dll`,
  `sourcemod.logic.dll`, `sourcepawn.jit.x86.dll`), and C++ extensions run
  cleanly, while `@metamod_source//:metamod_loader` crashes later on a
  `steamclient.dll` / `tier0.dll` background thread unless replaced with
  upstream's MSVC-built `server.dll`. Static inspection rules out
  `sh_memfuncinfo.h` (`patches/metamod-clang-thiscall-thunk.patch` decodes
  `ServerPlugin`'s `vcall` thunks at both `/Od` and `/O2`) and compiler/linker
  flags (identical to `_metamod_core_ep1_so.dll`). Suspects to test under
  `WINEDEBUG=+seh`:
  1. `fastbuild` (`/Od`, 366 KB) pulling in CRT debug/console-handler machinery
     (`__wassert`, `SetConsoleCtrlHandler`, `CreateThread`) that `-c opt`
     (160 KB) elides.
  2. `ServerPlugin::Load` calling `VirtualProtect(..., PAGE_EXECUTE_READWRITE)`
     on its `.rdata` vtable page (`loader/serverplugin.cpp`), which in
     `lld-link`'s layout shares `.rdata` with `LoadConfig` / `SEHandlerTable`
     inspected during Win32 exception dispatch (such as `tier0`'s `0x406D1388`
     thread-naming `RaiseException`).

## Non-x86 hosts

`sourcepawn_vm` falls back to `code-stubs-null.cpp` on non-x86 CPUs and
`_SPCOMP_DEFINES` sets `DARWIN` on macOS, so `sourcemod_plugin` and
`sourcemod_test` are wired for Apple silicon and Linux arm64 hosts (though CI
does not yet exercise an arm64 runner, and `code-stubs-null.cpp` does not
support fake natives).

Linux arm64 hosts still cannot cross-compile x86 server binaries because
`@llvm_linux` downloads the x64 LLVM release. A second repository using the
`Linux-ARM64` release would fix that.
