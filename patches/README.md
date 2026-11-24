# Patches

Applied to upstream sources when Bazel fetches them.

## Reproducible builds

Upstream embeds the build time in its binaries. These replace it with a fixed
date, in source because MSVC ignores attempts to redefine `__DATE__`.

- [`metamod-build-date-header.patch`](metamod-build-date-header.patch):
  fixes the date in `SOURCEMM_DATE`.
- [`metamod-build-date-version.patch`](metamod-build-date-version.patch):
  fixes `MMS_BUILD_TIMESTAMP`.
- [`sourcemod-build-date-api.patch`](sourcemod-build-date-api.patch):
  fixes the date in `SourceMod_Core::GetDate()`.
- [`sourcemod-build-date-version.patch`](sourcemod-build-date-version.patch):
  fixes `SM_BUILD_TIMESTAMP`.
- [`spcomp-source-date-epoch.patch`](spcomp-source-date-epoch.patch):
  makes `spcomp` stamp plugins with `SOURCE_DATE_EPOCH` when set.

## Windows cross-compilation

Upstream's Windows code assumes MSVC. These make it work with `clang-cl`.

- [`metamod-clang-thiscall-thunk.patch`](metamod-clang-thiscall-thunk.patch):
  SourceHook finds vtable slots by matching MSVC's thunk machine code. Matches
  Clang's too.
- [`hl2sdk-ep1-mathlib-base-clang.patch`](hl2sdk-ep1-mathlib-base-clang.patch):
  Clang rejects the 3DNow! assembly, naked functions, and implicit conversions.
  Uses C++ instead and makes the types explicit.
- [`hl2sdk-ep1-ssemath-clang.patch`](hl2sdk-ep1-ssemath-clang.patch):
  Clang's `__m128` has no `m128_f32`, and it rejects an implicit conversion.
  Uses the header's Linux union and casts the constant.

## Invalid code in `ep1`

- [`hl2sdk-ep1-memalloc-include.patch`](hl2sdk-ep1-memalloc-include.patch):
  `memalloc.h` uses `IsPowerOfTwo` without including its definition. Adds the
  include.
- [`hl2sdk-ep1-movzx-operand-size.patch`](hl2sdk-ep1-movzx-operand-size.patch):
  `movzx` is given a 32-bit variable, but only reads 8 or 16 bits. Adds `word
  ptr`.
