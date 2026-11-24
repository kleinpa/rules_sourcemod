"""Bzlmod module extension for SourceMod, Metamod:Source, HL2SDK, and cross-toolchains."""

load("//hl2sdk:repositories.bzl", "HL2SDK_BRANCHES", "hl2sdk_repository", "metamod_repository")
load("//linux:sysroot.bzl", "linux_sysroot")
load("//linux:toolchain.bzl", "llvm_linux")
load("//sourcemod:repositories.bzl", "sourcemod_curl_repository", "sourcemod_sdk_repository")
load("//windows:toolchain.bzl", "llvm_windows_toolchain")
load("//windows:xwin_sysroot.bzl", "xwin_sysroot")

_SDK_ATTRS = {
    "amtl_commit": attr.string(doc = "Override commit SHA for alliedmodders/amtl."),
    "amtl_sha256": attr.string(doc = "SHA256 for the amtl archive."),
    "safetyhook_commit": attr.string(doc = "Override commit SHA for alliedmodders/safetyhook."),
    "safetyhook_sha256": attr.string(doc = "SHA256 for the safetyhook archive."),
    "sourcemod_commit": attr.string(doc = "Override commit SHA for alliedmodders/sourcemod."),
    "sourcemod_sha256": attr.string(doc = "SHA256 for the sourcemod archive."),
    "sourcepawn_commit": attr.string(doc = "Override commit SHA for alliedmodders/sourcepawn."),
    "sourcepawn_sha256": attr.string(doc = "SHA256 for the sourcepawn archive."),
}

_METAMOD_ATTRS = {
    "amtl_commit": attr.string(doc = "Override commit SHA for Metamod's third_party/amtl."),
    "amtl_sha256": attr.string(doc = "SHA256 for Metamod's amtl archive."),
    "commit": attr.string(doc = "Override commit SHA for alliedmodders/metamod-source."),
    "sha256": attr.string(doc = "SHA256 for the metamod-source archive."),
}

_WINDOWS_CROSS_ATTRS = {
    "accept_license": attr.bool(
        mandatory = True,
        doc = "Must be True to accept the Microsoft Windows SDK and MSVC++ Runtime license (https://github.com/Jake-Shadle/xwin#license).",
    ),
}

def _non_empty_attrs(tag, names):
    kwargs = {}
    for name in names:
        val = getattr(tag, name)
        if val:
            kwargs[name] = val
    return kwargs

def _sourcemod_impl(mctx):
    sdk_kwargs = {}
    metamod_kwargs = {}
    enable_windows_cross = False

    for mod in mctx.modules:
        if not mod.is_root:
            if mod.tags.sdk or mod.tags.metamod or mod.tags.windows_cross_toolchain:
                fail("sourcemod extension tags may only be set by the root module (found in '{}')".format(mod.name))
            continue

        if len(mod.tags.sdk) > 1:
            fail("at most one sourcemod.sdk() tag may be specified")
        for tag in mod.tags.sdk:
            sdk_kwargs = _non_empty_attrs(tag, _SDK_ATTRS.keys())

        if len(mod.tags.metamod) > 1:
            fail("at most one sourcemod.metamod() tag may be specified")
        for tag in mod.tags.metamod:
            metamod_kwargs = _non_empty_attrs(tag, _METAMOD_ATTRS.keys())

        for tag in mod.tags.windows_cross_toolchain:
            if not tag.accept_license:
                fail("sourcemod.windows_cross_toolchain(accept_license = True) is required")
            enable_windows_cross = True

    sourcemod_sdk_repository(
        name = "sourcemod_sdk",
        **sdk_kwargs
    )
    sourcemod_curl_repository(
        name = "sourcemod_curl",
    )
    metamod_repository(
        name = "metamod_source",
        **metamod_kwargs
    )

    # Bazel fetches external repositories lazily; declaring all supported
    # branches here costs nothing until a target in that branch is requested.
    for branch in HL2SDK_BRANCHES:
        hl2sdk_repository(
            name = "hl2sdk_" + branch,
            branch = branch,
        )

    # Hermetic Linux toolchain; fetched only when //linux:all is registered and selected.
    linux_sysroot(
        name = "linux_sysroot_amd64",
        arch = "amd64",
    )
    linux_sysroot(
        name = "linux_sysroot_i386",
        arch = "i386",
    )
    llvm_linux(
        name = "llvm_linux",
        sysroot_x86_32 = "@linux_sysroot_i386//:sysroot",
        sysroot_x86_64 = "@linux_sysroot_amd64//:sysroot",
    )

    if enable_windows_cross:
        xwin_sysroot(
            name = "windows_x86_32_sysroot",
            accept_license = True,
            arch = "x86",
        )
        llvm_windows_toolchain(
            name = "llvm_toolchain_windows_x86_32",
            sysroot = "@windows_x86_32_sysroot//sysroot",
        )

    return mctx.extension_metadata(reproducible = True)

sourcemod = module_extension(
    implementation = _sourcemod_impl,
    doc = "Configures SourceMod, Metamod:Source, HL2SDK branches, and optional cross-compilation toolchains.",
    tag_classes = {
        "metamod": tag_class(
            attrs = _METAMOD_ATTRS,
            doc = "Overrides the pinned Metamod:Source commit (root module only).",
        ),
        "sdk": tag_class(
            attrs = _SDK_ATTRS,
            doc = "Overrides the pinned SourceMod / SourcePawn commits (root module only).",
        ),
        "windows_cross_toolchain": tag_class(
            attrs = _WINDOWS_CROSS_ATTRS,
            doc = "Opts into the Linux -> windows_x86_32 clang-cl + xwin cross-toolchain (root module only).",
        ),
    },
)
