"""Builds one Metamod:Source core per requested engine branch.

This is loaded by the generated BUILD file in @metamod_source, which passes the
branch list that //hl2sdk:repositories.bzl substituted into it. It exists as a
macro rather than as targets written out in metamod.BUILD.bazel because the
branch set is not known until the module graph is: a core has to name
`@hl2sdk_<branch>`, and naming a branch the extension was never asked to create
leaves @metamod_source referring to a repository that does not exist.

Naming is upstream's. The Metamod loader dlopens `metamod.<extension>.so` from
its own directory, where <extension> is the branch's manifest `extension` field
-- `2.css`, `2.tf2` -- so the file name is an interface, not a label.
"""

load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("@rules_sourcemod//sourcemod:warnings.bzl", "UPSTREAM_WARNING_COPTS")

# Translated from `configure_cxx()` in the AMBuildScript. The POSIX set maps the
# MSVC-spelled string functions the sources call to their C equivalents; without
# it `stricmp` is an undeclared identifier on Linux.
_GCC_DEFINES = [
    "stricmp=strcasecmp",
    "_stricmp=strcasecmp",
    "_snprintf=snprintf",
    "_vsnprintf=vsnprintf",
    "HAVE_STDINT_H",
    "GNUC",
]

PLATFORM_DEFINES = select({
    "@platforms//os:windows": ["WIN32", "_WINDOWS"],
    "@platforms//os:macos": ["OSX", "_OSX", "POSIX"] + _GCC_DEFINES,
    "//conditions:default": [
        "LINUX",
        "_LINUX",
        "POSIX",
        "_FILE_OFFSET_BITS=64",
    ] + _GCC_DEFINES,
})

CORE_COPTS = select({
    "@rules_cc//cc/compiler:msvc-cl": ["/W3", "/EHsc", "/GR-"],
    # c++14, not this repo's usual c++17 (see sourcemod/server.bzl's
    # _COPTS_COMMON): upstream's own AMBuildScript (configure_gcc()) targets
    # c++14 for Metamod specifically -- unlike SourceMod's separately
    # versioned build, which genuinely does target c++17. Metamod's loader
    # still has a `for (register size_t i = ...)` (loader/utility.cpp,
    # upstream, not ours to fix): under c++14 that's merely deprecated, and
    # UPSTREAM_WARNING_COPTS' `-Wno-register` (also upstream's own flag)
    # silences the deprecation warning -- but under ISO c++17 `register`
    # isn't deprecated, it's removed from the grammar, a hard error
    # -Wno-register cannot suppress no matter how permissive the rest of the
    # warning configuration is.
    "//conditions:default": [
        "-std=c++14",
        "-fPIC",
        "-fno-strict-aliasing",
        "-fno-rtti",
    ],
}) + UPSTREAM_WARNING_COPTS

# SourceHook's own sources, which every core compiles regardless of engine.
#
# The arch variants follow core/AMBuilder:
#   arch == x86:                sourcehook_hookmangen_x86.cpp
#   arch == x86_64 && !linux:   sourcehook_hookmangen_x86_64.cpp
#   arch == x86_64 &&  linux:   (nothing extra)
_SOURCEHOOK_SRCS = [
    "core/sourcehook/sourcehook.cpp",
    "core/sourcehook/sourcehook_hookmangen.cpp",
    "core/sourcehook/sourcehook_impl_chookidman.cpp",
    "core/sourcehook/sourcehook_impl_chookmaninfo.cpp",
    "core/sourcehook/sourcehook_impl_cproto.cpp",
    "core/sourcehook/sourcehook_impl_cvfnptr.cpp",
] + select({
    "@platforms//cpu:x86_32": ["core/sourcehook/sourcehook_hookmangen_x86.cpp"],
    Label("@rules_sourcemod//platforms:windows_x86_64_setting"): [
        "core/sourcehook/sourcehook_hookmangen_x86_64.cpp",
    ],
    Label("@rules_sourcemod//platforms:macos_x86_64_setting"): [
        "core/sourcehook/sourcehook_hookmangen_x86_64.cpp",
    ],
    "//conditions:default": [],
})

# HL2Library() adds this on Linux only: amtl's libstdc++ compatibility shims,
# which let the .so load against the old libstdc++ the engine ships.
_COMPAT_SRCS = select({
    "@platforms//os:linux": ["third_party/amtl/compat/stdcxx.cpp"],
    "//conditions:default": [],
})

def metamod_cores(branches):
    """Declares a `metamod_core_<branch>` target for each entry in `branches`.

    Args:
        branches: List of dicts with keys `branch` and `extension`, written
            into the BUILD file by //hl2sdk:repositories.bzl.
    """

    # Headers private to a core build. Kept out of :metamod_headers so the
    # extension-facing API stays what an extension actually includes -- adding
    # core/provider there would put it on every dependent's include path.
    #
    # `loader` is here because the core and the loader talk across a shared
    # interface (loader_bridge.h): HL2Library() puts the loader directory on the
    # core's include path even though the two are separate binaries.
    cc_library(
        name = "_metamod_core_hdrs",
        hdrs = native.glob(
            [
                "core/provider/*.h",
                "loader/*.h",
                "third_party/amtl/amtl/**/*.h",
            ],
            allow_empty = True,
        ),
        includes = [
            "core/provider",
            "loader",
            "third_party/amtl",
        ],
        visibility = ["//visibility:private"],
    )

    for spec in branches:
        _metamod_core(branch = spec["branch"], extension = spec["extension"])

def _metamod_core(branch, extension):
    hl2sdk = "@hl2sdk_{}".format(branch)

    srcs = native.glob(
        [
            "core/*.cpp",
            "core/provider/*.cpp",
        ],
        allow_empty = False,
    )

    # Depends on :hl2sdk_libs rather than :hl2sdk. Both carry the SDK's support
    # libraries, which the core needs to resolve ConVar/ConCommand at dlopen
    # time; :hl2sdk additionally pulls in :metamod_headers, which this target
    # already has and which would make the dependency read circularly.
    cc_library(
        name = "_metamod_core_{}_lib".format(branch),
        srcs = srcs + _SOURCEHOOK_SRCS + _COMPAT_SRCS,
        copts = CORE_COPTS,
        local_defines = ["_ALLOW_KEYWORD_MACROS"] + PLATFORM_DEFINES,
        # Nothing in the (source-less) cc_binary below references these objects
        # -- the engine looks them up by symbol after dlopen -- so without
        # alwayslink the linker drops every one and emits a valid but empty .so.
        alwayslink = True,
        deps = [
            ":_metamod_core_hdrs",
            ":metamod_headers",
            hl2sdk + "//:hl2sdk_libs",
        ],
        visibility = ["//visibility:private"],
    )

    cc_binary(
        name = "_metamod_core_{}_so".format(branch),
        linkshared = True,
        deps = [":_metamod_core_{}_lib".format(branch)],
        visibility = ["//visibility:private"],
    )

    copy_file(
        name = "metamod_core_{}".format(branch),
        src = ":_metamod_core_{}_so".format(branch),
        out = "metamod.{}.so".format(extension),
    )
