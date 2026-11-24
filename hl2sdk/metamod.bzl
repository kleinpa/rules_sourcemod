"""Shared flags and the per-branch core macro for the Metamod:Source build overlay."""

load("@rules_cc//cc:defs.bzl", "cc_binary")
load(
    "@rules_sourcemod//private:flags.bzl",
    "POSIX_COMPAT_DEFINES",
    "UPSTREAM_WARNING_COPTS",
    "UPSTREAM_WINDOWS_LINKOPTS",
    "WINDOWS_CRT_FEATURES",
)
load("@rules_sourcemod//private:shared_lib.bzl", "shared_lib_output")

PLATFORM_DEFINES = select({
    "@platforms//os:windows": ["WIN32", "_WINDOWS"],
    "//conditions:default": [
        "LINUX",
        "_LINUX",
        "POSIX",
        "_FILE_OFFSET_BITS=64",
    ] + POSIX_COMPAT_DEFINES,
})

# Metamod targets C++14 on GCC/Clang (`loader/utility.cpp` still uses `register`,
# which ISO C++17 removed as a hard error there; MSVC accepts it under /std:c++17
# and clang-cl passes -Wno-register).
CORE_COPTS = select({
    "@rules_cc//cc/compiler:msvc-cl": ["/W3", "/EHsc", "/GR-", "/Oy-"],
    "//conditions:default": [
        "-std=c++14",
        "-fPIC",
        "-fno-strict-aliasing",
        "-fno-rtti",
        "-fno-omit-frame-pointer",
        "-fvisibility=hidden",
        "-fvisibility-inlines-hidden",
    ],
}) + UPSTREAM_WARNING_COPTS

_SOURCEHOOK_SRCS = [
    "core/sourcehook/sourcehook.cpp",
    "core/sourcehook/sourcehook_hookmangen.cpp",
    "core/sourcehook/sourcehook_impl_chookidman.cpp",
    "core/sourcehook/sourcehook_impl_chookmaninfo.cpp",
    "core/sourcehook/sourcehook_impl_cproto.cpp",
    "core/sourcehook/sourcehook_impl_cvfnptr.cpp",
] + select({
    "@platforms//cpu:x86_32": ["core/sourcehook/sourcehook_hookmangen_x86.cpp"],
    "@rules_sourcemod//platforms:is_windows_x86_64": ["core/sourcehook/sourcehook_hookmangen_x86_64.cpp"],
    "//conditions:default": [],
})

_COMPAT_SRCS = select({
    "@platforms//os:linux": ["third_party/amtl/compat/stdcxx.cpp"],
    "//conditions:default": [],
})

def metamod_core(branch):
    """Declares `metamod_core_<branch>`, the `metamod.<extension>.<so|dll>` core for one engine branch.

    Args:
      branch: Engine branch key in `HL2SDK_BRANCHES`.
    """
    cc_binary(
        name = "_metamod_core_{}_so".format(branch),
        srcs = native.glob(["core/*.cpp", "core/provider/*.cpp"]) + _SOURCEHOOK_SRCS + _COMPAT_SRCS,
        copts = CORE_COPTS,
        features = WINDOWS_CRT_FEATURES,
        linkopts = UPSTREAM_WINDOWS_LINKOPTS,
        linkshared = True,
        local_defines = ["_ALLOW_KEYWORD_MACROS"] + PLATFORM_DEFINES,
        visibility = ["//visibility:private"],
        deps = [
            ":metamod_core_headers",
            ":metamod_headers",
            "@hl2sdk_{}//:hl2sdk_libs".format(branch),
        ],
    )
    shared_lib_output(
        name = "metamod_core_" + branch,
        binary = ":_metamod_core_{}_so".format(branch),
    )
