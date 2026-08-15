"""Warning suppressions for the AlliedModders and Valve sources.

Everything compiled from @hl2sdk_*, @metamod_source and @sourcemod_sdk is
third-party code, some of it twenty years old, and none of it is warning-clean
under a current compiler with Bazel's default `-Wall`. The noise is not a
finding: it is the same code upstream ships, and a build that prints two hundred
warnings from other people's sources is one where a warning about *our* code
goes unread.

The list is upstream's own. `configure_gcc()` in SourceMod's AMBuildScript
suppresses most of these, so it is the flag set the code was written against;
building it with anything stricter is inventing a standard its authors never
applied. The version gates upstream carries (`if cxx.version >= 'gcc-4.8'`) are
dropped, since nothing that old can compile the C++17 this tree now requires.

These are GCC spellings, and only GCC's. Upstream supports both families and
switches flags between them, but doing that here means maintaining two lists
whose contents cannot be checked against each other by anything but a build on
each compiler. A clang build still works; it lands in the same branch, does not
recognize a handful of the options -- `-Wno-template-id-cdtor` and
`-Wno-maybe-uninitialized` among them -- and says so whenever it emits any other
diagnostic. That is the cost of the simplification, and it is paid in log lines
rather than in behavior.

One diagnostic survives and cannot be added here. `smsdk_ext.cpp` replaces
`operator delete` without `noexcept`, which GCC reports as "declaration of
'void operator delete(void*)' has a different exception specifier" -- and
reports unconditionally, with no controlling -W flag to name. Twelve lines per
build, from a construct upstream chose.

Warnings about code in *this* repository are not covered by any of this: there
is no C++ here, only build definitions.
"""

_GCC = [
    # From upstream's configure_gcc().
    "-Wno-unused",
    "-Wno-switch",
    "-Wno-array-bounds",
    "-Wno-unknown-pragmas",
    "-Wno-dangling-else",
    "-Wno-narrowing",
    # Clang's own spelling of the above for list-initialization specifically
    # (GCC's -Wno-narrowing doesn't cover it under Clang) -- e.g. ep1's
    # mathlib/ssemath.h initializes a signed int32 array element with
    # 0x80000000, which doesn't fit as a *signed* value; upstream's own
    # compilers never enforced C++11 list-init narrowing rules against it.
    "-Wno-c++11-narrowing",
    "-Wno-non-virtual-dtor",
    "-Wno-overloaded-virtual",
    "-Wno-delete-non-virtual-dtor",
    "-Wno-unused-result",
    "-Wno-invalid-offsetof",
    "-Wno-maybe-uninitialized",
    "-Wno-class-memaccess",
    "-Wno-packed-not-aligned",
    # The sources still use the `register` keyword that C++17 removed.
    "-Wno-register",
    # Upstream passes -Wno-deprecated for the same reason: this is C++17-era
    # code using what C++17 deprecated, e.g. wstring_convert in the SourcePawn
    # compiler's codepage handling.
    "-Wno-deprecated-declarations",
    #
    # Not in upstream's list, which predates the compilers that emit these.
    #
    # SourceHook spells constructors and destructors `CVector<T>()`, which C++20
    # removed and GCC 14 began warning about ahead of time.
    "-Wno-template-id-cdtor",
    # The HL2SDK's container and string code.
    "-Wno-sign-compare",
    "-Wno-nonnull-compare",
    "-Wno-ignored-attributes",
    # snprintf into a fixed buffer whose size GCC cannot prove is enough.
    "-Wno-format-truncation",
]

# Upstream's MSVC configuration suppresses nothing comparable, so neither does
# this: /W3 there is already quiet about the constructs GCC flags -- except
# for one, which isn't actually about warning-quietness. `register` is
# gone from the ISO C++17 grammar (not just deprecated), and the sources
# still use it (e.g. SourceMod's own core/logic/MersenneTwister.h); Clang
# (both a native clang-cl and this module's cross-compiling one, see
# windows/xwin_sysroot.bzl) treats that as a hard error unless told
# otherwise via -Wno-register, gated behind the same -Wregister spelling
# it uses everywhere else. Real MSVC has no such diagnostic to begin with
# (it silently accepts the extension), so this is a no-op there -- and
# harmless even if cl.exe treated it as unrecognized, since MSVC downgrades
# an unknown switch to a D9002 warning rather than failing the build.
UPSTREAM_WARNING_COPTS = select({
    "@rules_cc//cc/compiler:msvc-cl": ["-Wno-register"],
    "//conditions:default": _GCC,
})

# The standard Win32 import libraries upstream links into every Windows
# binary -- both SourceMod's and Metamod's own AMBuildScript apply this
# same list (`configure_msvc()`/`cxx.like('msvc')`) unconditionally, not
# gated per-target by whether that particular binary calls into one of
# them. They are not pulled in by default the way e.g. kernel32.lib often
# is: Metamod's loader (loader/utility.cpp's mm_GetGameName) calls
# Shell32's CommandLineToArgvW and fails to link without shell32.lib
# explicitly present, which is what surfaced this list was missing here at
# all -- unlike UPSTREAM_WARNING_COPTS above, nothing analogous existed
# before, since nothing had built a Windows binary that actually called
# into one of the less-common libraries in the list.
UPSTREAM_WINDOWS_LINKOPTS = select({
    "@platforms//os:windows": [
        "kernel32.lib",
        "user32.lib",
        "gdi32.lib",
        "winspool.lib",
        "comdlg32.lib",
        "advapi32.lib",
        "shell32.lib",
        "ole32.lib",
        "oleaut32.lib",
        "uuid.lib",
        "odbc32.lib",
        "odbccp32.lib",
    ],
    "//conditions:default": [],
})
