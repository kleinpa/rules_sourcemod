"""`sourcemod_extension` — builds a SourceMod C++ extension shared library."""

load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")
load("//hl2sdk:repositories.bzl", "HL2SDK_BRANCHES", "branch_target_compatible_with")
load(
    "//private:flags.bzl",
    "UPSTREAM_WARNING_COPTS",
    "UPSTREAM_WINDOWS_LINKOPTS",
    "WINDOWS_CRT_FEATURES",
)
load("//private:shared_lib.bzl", "SHARED_LIB_ATTRS", "select_shared_lib")
load("//spcomp:library.bzl", "SourcePawnInfo", "source_pawn_info_from_hdrs", "sourcemod_library")

_COPTS = select({
    Label("@rules_cc//cc/compiler:msvc-cl"): ["/W3", "/EHsc", "/GR-", "/Oy-"],
    "//conditions:default": [
        "-pipe",
        "-fno-strict-aliasing",
        "-Wall",
        "-fvisibility=hidden",
        "-fvisibility-inlines-hidden",
        "-fno-exceptions",
        "-fno-threadsafe-statics",
        "-fno-omit-frame-pointer",
    ],
}) + UPSTREAM_WARNING_COPTS

_LINKOPTS = select({
    Label("@platforms//os:windows"): [],
    "//conditions:default": [
        "-Wl,--exclude-libs,ALL",
        "-lm",
        "-static-libstdc++",
        "-static-libgcc",
    ],
}) + UPSTREAM_WINDOWS_LINKOPTS

# Forwarded to every generated target, not just the cc_binary.
_COMMON_ATTR_NAMES = (
    "compatible_with",
    "exec_compatible_with",
    "tags",
    "target_compatible_with",
    "testonly",
)

def _rename_extension_impl(ctx):
    src = select_shared_lib(ctx)
    is_x86_64 = ctx.target_platform_has_constraint(
        ctx.attr._x86_64_constraint[platform_common.ConstraintValueInfo],
    )
    renamed = ctx.actions.declare_file("{}.{}".format(ctx.attr.stem, src.extension))
    ctx.actions.symlink(output = renamed, target_file = src)

    ext_dest = "addons/sourcemod/extensions/x64" if is_x86_64 else "addons/sourcemod/extensions"
    dest_src_map = {"{}/{}".format(ext_dest, renamed.basename): renamed}
    out_files = [renamed]

    if ctx.attr.autoload_name:
        autoload = ctx.actions.declare_file("{}.autoload".format(ctx.attr.autoload_name))
        ctx.actions.write(output = autoload, content = "")
        # SourceMod's TryAutoload() always scans extensions/, never extensions/x64/.
        dest_src_map["addons/sourcemod/extensions/{}".format(autoload.basename)] = autoload
        out_files.append(autoload)

    providers = [
        DefaultInfo(files = depset(out_files)),
        PackageFilesInfo(
            dest_src_map = dest_src_map,
            attributes = {"mode": "0755"},
        ),
    ]
    if ctx.files.pawn_hdrs:
        providers.append(source_pawn_info_from_hdrs(
            ctx = ctx,
            hdrs = ctx.files.pawn_hdrs,
            strip_include_prefix = ctx.attr.pawn_strip_include_prefix,
        ))
    return providers

_rename_extension = rule(
    implementation = _rename_extension_impl,
    doc = "Renames a built shared library to `<stem>.<so|dll>` with rules_pkg and optional SourcePawn metadata.",
    attrs = dict(
        SHARED_LIB_ATTRS,
        autoload_name = attr.string(
            default = "",
            doc = "If non-empty, emits `<autoload_name>.autoload` into `addons/sourcemod/extensions/`.",
        ),
        pawn_hdrs = attr.label_list(
            allow_files = [".inc"],
            doc = "Companion `.inc` files exposed via `SourcePawnInfo` to `sourcemod_plugin` `deps`.",
        ),
        pawn_strip_include_prefix = attr.string(
            default = "",
            doc = "Prefix stripped from `pawn_hdrs` when computing `-i` include directories.",
        ),
        stem = attr.string(
            mandatory = True,
            doc = "Output filename stem before `.so`/`.dll` (e.g. `my_ext.ext` or `my_ext.ext.2.tf2`).",
        ),
        _x86_64_constraint = attr.label(
            default = Label("@platforms//cpu:x86_64"),
        ),
    ),
    provides = [PackageFilesInfo],
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
        features = [],
        extension_name = None,
        branch = None,
        game_server_hdrs = False,
        autoload = False,
        pawn_hdrs = [],
        pawn_strip_include_prefix = "",
        visibility = None,
        **kwargs):
    """Builds a SourceMod extension (`<stem>.ext[.<engine>].<so|dll>`) with `PackageFilesInfo`.

    Args:
      name: Target name (and default output basename).
      srcs: C++ source files for the extension (may be empty if supplied via `deps`).
      hdrs: Headers used by `srcs` (must include `smsdk_config.h` here or in `deps`).
      deps: Additional `cc_library` dependencies.
        Note: if extension implementation code is placed in a separate `cc_library` in
        `deps`, mark that `cc_library` `alwayslink = True` if any of its translation
        units register natives via static initializers not referenced from `SMEXT_LINK`.
      copts: Extra compiler options.
      defines: Extra preprocessor defines.
      linkopts: Extra linker options.
      includes: Extra include directories.
      features: Extra C++ toolchain features.
      extension_name: Output basename before `.ext` (defaults to `name`).
      branch: Optional HL2SDK branch key (`"css"`, `"tf2"`, `"l4d2"`, `"sdk2013"`, `"ep1"`).
        Adds `@hl2sdk_<branch>//:hl2sdk`, applies platform compatibility constraints, and
        emits `<extension_name>.ext.<engine>.<so|dll>`.
      game_server_hdrs: When `branch` is set, also depend on `@hl2sdk_<branch>//:hl2sdk_game_server`.
      autoload: If `True`, emits `<extension_name>.autoload` into `addons/sourcemod/extensions/`.
      pawn_hdrs: Companion `.inc` headers exposed via `SourcePawnInfo` (so `sourcemod_plugin`
        targets can depend directly on `deps = [":<name>"]` or `deps = [":<name>_inc"]` without
        leaking `.inc` files into `pkg_tar`).
      pawn_strip_include_prefix: Prefix stripped from `pawn_hdrs` when computing `-i` search paths.
      visibility: Target visibility.
      **kwargs: Common rule attributes (`tags`, `testonly`, `target_compatible_with`,
        `exec_compatible_with`, `compatible_with`) forwarded to all targets; remaining
        attributes forwarded to the underlying `cc_binary`.
    """
    if game_server_hdrs and not branch:
        fail("game_server_hdrs = True requires setting branch = '<hl2sdk_branch>'")

    ext_basename = extension_name or name
    sdk_deps = [Label("@sourcemod_sdk//:sourcemod_headers")]
    branch_compat = []

    if branch != None:
        if branch not in HL2SDK_BRANCHES:
            fail("unknown HL2SDK branch '{}'; expected one of {}".format(
                branch,
                sorted(HL2SDK_BRANCHES.keys()),
            ))
        spec = HL2SDK_BRANCHES[branch]
        stem = "{}.ext.{}".format(ext_basename, spec["extension"])
        sdk_deps.append(Label("@hl2sdk_{}//:hl2sdk".format(branch)))
        if game_server_hdrs:
            sdk_deps.append(Label("@hl2sdk_{}//:hl2sdk_game_server".format(branch)))
        branch_compat = [Label(c) for c in branch_target_compatible_with(spec)]
    else:
        stem = "{}.ext".format(ext_basename)

    common_attrs = {
        k: kwargs.pop(k)
        for k in _COMMON_ATTR_NAMES
        if k in kwargs
    }
    if branch_compat:
        existing_compat = common_attrs.get("target_compatible_with")
        if existing_compat == None:
            common_attrs["target_compatible_with"] = branch_compat
        elif type(existing_compat) == "list":
            merged = list(existing_compat)
            for c in branch_compat:
                if c not in merged:
                    merged.append(c)
            common_attrs["target_compatible_with"] = merged

    if pawn_hdrs:
        inc_attrs = {
            k: common_attrs[k]
            for k in ("tags", "testonly")
            if k in common_attrs
        }
        sourcemod_library(
            name = name + "_inc",
            hdrs = pawn_hdrs,
            strip_include_prefix = pawn_strip_include_prefix,
            visibility = visibility,
            **inc_attrs
        )

    # `cc_binary` has no `hdrs`/`includes`, so sources live in a library.
    cc_library(
        name = name + "_lib",
        srcs = srcs,
        hdrs = hdrs,
        copts = _COPTS + copts,
        defines = defines,
        features = WINDOWS_CRT_FEATURES + features,
        includes = includes,
        deps = sdk_deps + deps,
        alwayslink = True,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    # Compile smsdk_ext.cpp directly on the binary so `--exclude-libs,ALL`
    # never hides the `GetSMExtAPI` entry point when a linker uses `.a` archives.
    cc_binary(
        name = name + "_shared",
        srcs = [Label("@sourcemod_sdk//:public/smsdk_ext.cpp")],
        copts = _COPTS + copts,
        features = WINDOWS_CRT_FEATURES + features,
        linkopts = _LINKOPTS + linkopts,
        linkshared = True,
        deps = [":" + name + "_lib"],
        visibility = ["//visibility:private"],
        **(dict(common_attrs, **kwargs))
    )

    _rename_extension(
        name = name,
        binary = ":" + name + "_shared",
        stem = stem,
        autoload_name = ext_basename if autoload else "",
        pawn_hdrs = pawn_hdrs,
        pawn_strip_include_prefix = pawn_strip_include_prefix,
        visibility = visibility,
        **common_attrs
    )
