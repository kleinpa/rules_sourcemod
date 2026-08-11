"""Builds one Metamod:Source core per requested engine branch.

This is loaded by the generated BUILD file in @metamod_source, which passes the
branch list that //hl2sdk:repositories.bzl substituted into it. It exists as a
macro rather than as targets written out in metamod.BUILD.bazel because the
branch set is not known until the module graph is: a core has to name
`@hl2sdk_<branch>`, and naming a branch the extension was never asked to create
leaves @metamod_source referring to a repository that does not exist.

Naming is upstream's. The Metamod loader dlopens `metamod.<extension>.so` from
its own directory, where <extension> is the branch's manifest `extension` field
-- `2.css`, `2.cs2` -- so the file name is an interface, not a label.
"""

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
    "//conditions:default": [
        "-std=c++17",
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
        branches: List of dicts with keys `branch`, `extension` and `source2`,
            written into the BUILD file by //hl2sdk:repositories.bzl.
    """

    # Headers private to a core build. Kept out of :metamod_headers so the
    # extension-facing API stays what an extension actually includes -- adding
    # core/provider there would put it on every dependent's include path.
    #
    # `loader` is here because the core and the loader talk across a shared
    # interface (loader_bridge.h): HL2Library() puts the loader directory on the
    # core's include path even though the two are separate binaries.
    #
    # The provider subdirectories exist only on the 2.0 line, where the Source 1
    # and Source 2 providers live side by side; on 1.12 there is just
    # core/provider, so the globs are allowed to come up empty.
    cc_library(
        name = "_metamod_core_hdrs",
        hdrs = native.glob(
            [
                "core/provider/*.h",
                "core/provider/source/*.h",
                "core/provider/source2/*.h",
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
        _metamod_core(
            branch = spec["branch"],
            extension = spec["extension"],
            source2 = spec["source2"],
        )

def _metamod_core(branch, extension, source2):
    hl2sdk = "@hl2sdk_{}".format(branch)

    if source2:
        # provider/source2 replaces provider/source, and vsp_bridge.cpp goes
        # with it: Valve Server Plugins are a Source 1 concept, and the file
        # does not compile against a Source 2 SDK.
        srcs = native.glob(
            ["core/*.cpp"],
            exclude = ["core/vsp_bridge.cpp"],
            allow_empty = False,
        ) + [
            "core/provider/provider_base.cpp",
            "core/provider/source2/provider_source2.cpp",
            # memoverride.cpp and convar.cpp are compiled into the module
            # itself rather than linked from a library; see
            # :source2_module_srcs in the SDK overlay.
            hl2sdk + "//:source2_module_srcs",
        ]
        local_defines = ["META_IS_SOURCE2"]
        deps = [hl2sdk + "//:hl2sdk_libs"]
    else:
        srcs = native.glob(
            [
                "core/*.cpp",
                "core/provider/*.cpp",
            ],
            allow_empty = False,
        ) + native.glob(
            # 2.0 moved the Source 1 provider down a level, next to the Source 2
            # one. On 1.12 there is no such directory and the files are the ones
            # core/provider/*.cpp already matched.
            ["core/provider/source/*.cpp"],
            allow_empty = True,
        )
        local_defines = ["_ALLOW_KEYWORD_MACROS"]
        deps = [hl2sdk + "//:hl2sdk_libs"]

    # Depends on :hl2sdk_libs rather than :hl2sdk. Both carry the SDK's support
    # libraries, which the core needs to resolve ConVar/ConCommand at dlopen
    # time; :hl2sdk additionally pulls in :metamod_headers, which this target
    # already has and which would make the dependency read circularly.
    cc_library(
        name = "_metamod_core_{}_lib".format(branch),
        srcs = srcs + _SOURCEHOOK_SRCS + _COMPAT_SRCS,
        copts = CORE_COPTS,
        local_defines = local_defines + PLATFORM_DEFINES,
        # Nothing in the (source-less) cc_binary below references these objects
        # -- the engine looks them up by symbol after dlopen -- so without
        # alwayslink the linker drops every one and emits a valid but empty .so.
        alwayslink = True,
        deps = [
            ":_metamod_core_hdrs",
            ":metamod_headers",
        ] + deps,
        visibility = ["//visibility:private"],
    )

    cc_binary(
        name = "_metamod_core_{}_so".format(branch),
        linkshared = True,
        deps = [":_metamod_core_{}_lib".format(branch)],
        visibility = ["//visibility:private"],
    )

    native.genrule(
        name = "metamod_core_{}".format(branch),
        srcs = [":_metamod_core_{}_so".format(branch)],
        outs = ["metamod.{}.so".format(extension)],
        cmd = "cp $(SRCS) $@",
    )
