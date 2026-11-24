"""Shared C++ compiler flags, defines, and linker settings across SourceMod, Metamod, and HL2SDK."""

# Upstream AMBuild links all Windows deliverables (Metamod, SourceMod, spcomp,
# extensions) against the static MSVC CRT (/MT or /MTd) so DLLs do not depend
# on a separate msvcp140/vcruntime140 install. Ignored by Unix toolchains.
WINDOWS_CRT_FEATURES = ["static_link_msvcrt"]

# Warning suppressions matching upstream AMBuild's configure_gcc() plus modern
# GCC 14+ diagnostics triggered by third-party Valve/AlliedModders headers.
# Label() keys bind in rules_sourcemod's repo mapping when expanded in consumer repos.
_GCC_WARNING_COPTS = [
    "-Wno-unused",
    "-Wno-switch",
    "-Wno-array-bounds",
    "-Wno-unknown-pragmas",
    "-Wno-dangling-else",
    "-Wno-narrowing",
    "-Wno-non-virtual-dtor",
    "-Wno-overloaded-virtual",
    "-Wno-delete-non-virtual-dtor",
    "-Wno-unused-result",
    "-Wno-invalid-offsetof",
    "-Wno-maybe-uninitialized",
    "-Wno-class-memaccess",
    "-Wno-packed-not-aligned",
    "-Wno-register",
    "-Wno-deprecated-declarations",
    "-Wno-template-id-cdtor",  # CVector<T>() in SourceHook under GCC 14+ (CWG 2237)
    "-Wno-reorder",
    "-Wno-sign-compare",
    "-Wno-nonnull-compare",
    "-Wno-ignored-attributes",
    "-Wno-format-truncation",
]

# MSVC /W3 is already quiet on these constructs and cl.exe rejects -Wno-* with D8021.
UPSTREAM_WARNING_COPTS = select({
    Label("@rules_cc//cc/compiler:msvc-cl"): [],
    "//conditions:default": _GCC_WARNING_COPTS,
})

# Standard Win32 import libraries upstream's configure_msvc() links unconditionally.
UPSTREAM_WINDOWS_LINKOPTS = select({
    Label("@platforms//os:windows"): [
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

# Maps MSVC-spelled C string functions used across Metamod and SourceMod headers.
POSIX_COMPAT_DEFINES = [
    "stricmp=strcasecmp",
    "_stricmp=strcasecmp",
    "_snprintf=snprintf",
    "_vsnprintf=vsnprintf",
    "HAVE_STDINT_H",
    "GNUC",
]

_MSVC_COMMON_DEFINES = [
    "WIN32",
    "_WINDOWS",
    "_CRT_SECURE_NO_DEPRECATE",
    "_CRT_SECURE_NO_WARNINGS",
    "_CRT_NONSTDC_NO_DEPRECATE",
    "_ITERATOR_DEBUG_LEVEL=0",
    "COMPILER_MSVC",
]

SOURCEMOD_PLATFORM_DEFINES = select({
    Label("@rules_sourcemod//platforms:is_windows_x86_64"): _MSVC_COMMON_DEFINES + ["WIN64", "COMPILER_MSVC64"],
    Label("@platforms//os:windows"): _MSVC_COMMON_DEFINES + ["COMPILER_MSVC32"],
    "//conditions:default": ["_LINUX", "POSIX", "COMPILER_GCC"] + POSIX_COMPAT_DEFINES,
})

# Shared compiler and linker flags for SourceMod server components and bundled extensions.
SERVER_COPTS = select({
    Label("@rules_cc//cc/compiler:msvc-cl"): ["/W3", "/EHsc", "/GR-", "/Oy-", "/std:c++17"],
    "//conditions:default": [
        "-std=c++17",
        "-fPIC",
        "-fno-strict-aliasing",
        "-fno-rtti",
        "-fno-omit-frame-pointer",
    ],
}) + UPSTREAM_WARNING_COPTS

SERVER_LINKOPTS = select({
    Label("@platforms//os:linux"): ["-lpthread", "-lrt", "-ldl"],
    "//conditions:default": [],
}) + UPSTREAM_WINDOWS_LINKOPTS
