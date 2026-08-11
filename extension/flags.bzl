"""Compiler/linker configuration for SourceMod extensions.

This is a direct translation of the `configure_gcc` / `configure_msvc` /
`configure_linux` / `configure_windows` methods in the AMBuild template these
rules replace. Flags that only existed to support the HL2SDK are deliberately
dropped -- see README.md ("What was removed and why").

The 32-bit (`-m32`) requirement is *not* expressed here. Under Bazel, target
architecture is a platform concern, not a per-rule copt: building for 32-bit is
done with `--platforms=@rules_sourcemod//platforms:linux_x86_32`, which drives the
toolchain rather than smuggling an ABI flag into every compile action.
"""

load("//sourcemod:warnings.bzl", "UPSTREAM_WARNING_COPTS")

# Code generation and ABI only. The warning suppressions that used to be
# repeated here now come from //sourcemod:warnings.bzl, which is the same set
# upstream's configure_gcc() applies to every target in its build, extensions
# included -- and having them in one place is what keeps the two from drifting.
_GCC_LIKE_COPTS = [
    "-pipe",
    "-fno-strict-aliasing",
    "-Wall",
    "-fvisibility=hidden",
    "-fvisibility-inlines-hidden",
    # SourceMod's ABI: extensions must not throw across the plugin boundary,
    # and its interfaces use non-virtual destructors by design.
    "-fno-exceptions",
    "-fno-threadsafe-statics",
]

_MSVC_COPTS = [
    "/W3",
    "/EHsc",
    "/GR-",
    # Don't omit the frame pointer; matches upstream, which re-adds this after
    # its optimization flags.
    "/Oy-",
]

EXTENSION_COPTS = select({
    "@rules_cc//cc/compiler:msvc-cl": _MSVC_COPTS,
    "//conditions:default": _GCC_LIKE_COPTS,
}) + UPSTREAM_WARNING_COPTS

# The SDK's platform defines are not restated here: they are declared once in
# //sourcemod:defines.bzl and propagated by `@sourcemod_sdk//:sourcemod_headers`
# as `defines`, so every target that depends on the SDK -- including a plain
# cc_library the consumer writes themselves -- already receives them.

EXTENSION_LINKOPTS = select({
    # The MSVC toolchain already links the common Win32 import libraries.
    # Anything beyond that is extension-specific and belongs in the consuming
    # target's `linkopts`.
    "@platforms//os:windows": [],
    "@platforms//os:macos": ["-liconv"],
    "//conditions:default": [
        # Extensions load into srcds alongside other extensions; never export
        # symbols from statically linked dependencies.
        "-Wl,--exclude-libs,ALL",
        "-lm",
        # The game server ships an old libstdc++; link ours in statically so the
        # extension does not depend on the host's C++ runtime.
        "-static-libstdc++",
        "-static-libgcc",
    ],
})
