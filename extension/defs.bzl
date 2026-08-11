"""`sourcemod_extension` — builds a SourceMod extension shared library.

This replaces the AMBuild `HL2Project`/`HL2Config` machinery. The compiler and
linker settings below are a direct translation of the flags that template
applied; see `flags.bzl` for the per-toolchain mapping.
"""

load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")
load("//extension:flags.bzl", "EXTENSION_COPTS", "EXTENSION_LINKOPTS")
load("//sourcemod:providers.bzl", "SourceModPackageInfo", "package_providers")

def _rename_extension_impl(ctx):
    """Copies the linked library to the filename SourceMod's loader expects.

    cc_binary(linkshared) names its output after the target, and the correct
    extension (.so / .dll) is only known once the target platform is resolved.
    A genrule cannot express that -- `outs` must be known at loading time -- so
    the rename happens in a rule, where the target configuration is available.
    """
    is_windows = ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    )
    is_x86_64 = ctx.target_platform_has_constraint(
        ctx.attr._x86_64_constraint[platform_common.ConstraintValueInfo],
    )

    # On Windows, linking a shared library also produces an import .lib; select
    # the loadable module specifically rather than assuming a single output.
    wanted = "dll" if is_windows else "so"
    candidates = [f for f in ctx.files.binary if f.extension == wanted]
    if not candidates:
        fail("no '.{}' output found among: {}".format(
            wanted,
            [f.short_path for f in ctx.files.binary],
        ))
    src = candidates[0]

    renamed = ctx.actions.declare_file("{}.ext.{}".format(ctx.label.name, wanted))
    ctx.actions.symlink(output = renamed, target_file = src)

    # SourceMod's loader only scans extensions/x64 on a 64-bit target, the
    # same way sourcemod_server() places its own bundled extensions there --
    # see that macro's _X86_64-keyed selects for the same distinction.
    dest = "addons/sourcemod/extensions/x64" if is_x86_64 else "addons/sourcemod/extensions"

    return [
        DefaultInfo(files = depset([renamed])),
    ] + package_providers(dest, [renamed])

_rename_extension = rule(
    implementation = _rename_extension_impl,
    doc = "Renames a built shared library to the SourceMod extension filename.",
    attrs = {
        "binary": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "_windows_constraint": attr.label(
            default = Label("@platforms//os:windows"),
        ),
        "_x86_64_constraint": attr.label(
            default = Label("@platforms//cpu:x86_64"),
        ),
    },
    provides = [PackageFilesInfo, SourceModPackageInfo],
)

def sourcemod_extension(
        name,
        srcs = [],
        hdrs = [],
        deps = [],
        copts = [],
        defines = [],
        linkopts = [],
        includes = [],
        visibility = None,
        **kwargs):
    """Builds a SourceMod extension as a loadable shared library.

    Produces a `<name>.ext.so` (or `.dll` on Windows) that SourceMod can load
    from `addons/sourcemod/extensions`, plus packaging metadata so the result
    can be handed straight to rules_pkg's `pkg_tar`/`pkg_zip`.

    The extension is linked against the SourceMod SDK headers and
    `smsdk_ext.cpp`, which implements the extension entry points SourceMod
    calls into.

    The extension's own code may be given inline via `srcs`, or built separately
    as a plain `cc_library` and passed through `deps`:

        cc_library(
            name = "core",
            srcs = ["extension.cpp"],
            hdrs = ["extension.h", "smsdk_config.h"],
            includes = ["."],
            deps = ["@sourcemod_sdk//:sourcemod_headers"],
        )

        sourcemod_extension(
            name = "my_extension",
            deps = [":core"],
        )

    A `deps`-supplied library must still export `smsdk_config.h` (via `hdrs` and
    `includes`), because the SDK's `smsdk_ext.cpp` includes it and is compiled by
    this rule.

    Args:
      name: target name; also the extension's base filename.
      srcs: C++ source files for the extension. May be empty if the code is
        supplied through `deps`.
      hdrs: headers used by srcs.
      deps: additional cc_library dependencies. Linked with alwayslink, so a
        library holding SMEXT_LINK or native registrations is not dropped.
      copts: extra compiler options.
      defines: extra preprocessor defines.
      linkopts: extra linker options.
      includes: extra include directories.
      visibility: target visibility.
      **kwargs: forwarded to the underlying cc_binary.
    """

    # smsdk_ext.cpp is compiled per-extension rather than shared, because it is
    # configured by the consumer's smsdk_config.h (which selects the SourceMod
    # interfaces to enable). Two extensions in one repo can legitimately want
    # different configurations.
    # `Label()` is resolved in this file's repo mapping, so @sourcemod_sdk stays
    # visible even though the consuming module never declares it.
    smsdk_src = Label("@sourcemod_sdk//:public/smsdk_ext.cpp")
    sdk_headers = Label("@sourcemod_sdk//:sourcemod_headers")

    # `srcs` may be empty when the extension's code is supplied entirely through
    # `deps` as a cc_library. Everything here is linked with alwayslink so the
    # SMEXT_LINK global and the extension's natives are not dropped as unused --
    # nothing in the shared library references them, SourceMod finds them by
    # symbol after loading.
    cc_library(
        name = name + "_lib",
        srcs = [smsdk_src] + srcs,
        hdrs = hdrs,
        copts = EXTENSION_COPTS + copts,
        defines = defines,
        includes = includes,
        deps = [sdk_headers] + deps,
        alwayslink = True,
        visibility = ["//visibility:private"],
    )

    cc_binary(
        name = name + "_shared",
        copts = EXTENSION_COPTS + copts,
        defines = defines,
        linkopts = EXTENSION_LINKOPTS + linkopts,
        linkshared = True,
        deps = [":" + name + "_lib"],
        visibility = ["//visibility:private"],
        **kwargs
    )

    _rename_extension(
        name = name,
        binary = ":" + name + "_shared",
        visibility = visibility,
    )
