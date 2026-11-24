"""`sourcemod_plugin` — compiles a SourcePawn (.sp) source file into a .smx plugin."""

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")
load("//private:shared_lib.bzl", "package_files_info")
load("//spcomp:library.bzl", "SourcePawnInfo")

# 1980-01-01T00:00:00Z, matching `Jan  1 1980 00:00:00` in //patches/*-build-date-*.patch
# so spcomp's SOURCE_DATE_EPOCH stamps deterministic `__DATE__`/`__TIME__` into .smx output.
_BUILD_DATE_EPOCH = "315532800"

def _format_define(define):
    # spcomp treats bare arguments without `=` as input source filenames.
    return define if "=" in define else define + "=1"

def _sourcemod_plugin_impl(ctx):
    toolchain = ctx.toolchains["//spcomp:toolchain_type"].spcomp
    smx = ctx.actions.declare_file((ctx.attr.plugin_name or ctx.label.name) + ".smx")

    # Explicit `deps` and `includes` precede the stdlib root (where `sourcemod.inc`
    # lives) so callers (e.g. `sourcemod_test`'s standalone `<float>`) can shadow stdlib headers.
    include_dirs = []
    transitive_hdrs = [toolchain.stdlib_includes]
    transitive_srcs = []

    for dep in ctx.attr.deps:
        sp_info = dep[SourcePawnInfo]
        for inc_dir in sp_info.include_dirs.to_list():
            if inc_dir not in include_dirs:
                include_dirs.append(inc_dir)
        transitive_hdrs.append(sp_info.transitive_hdrs)
        transitive_srcs.append(sp_info.transitive_srcs)

    for dep in ctx.attr.includes:
        if SourcePawnInfo in dep:
            sp_info = dep[SourcePawnInfo]
            for inc_dir in sp_info.include_dirs.to_list():
                if inc_dir not in include_dirs:
                    include_dirs.append(inc_dir)
            transitive_hdrs.append(sp_info.transitive_hdrs)
            transitive_srcs.append(sp_info.transitive_srcs)
        else:
            for inc in dep[DefaultInfo].files.to_list():
                if inc.dirname not in include_dirs:
                    include_dirs.append(inc.dirname)
            transitive_hdrs.append(dep[DefaultInfo].files)

    for f in toolchain.stdlib_includes.to_list():
        if f.basename == "sourcemod.inc" and f.dirname not in include_dirs:
            include_dirs.append(f.dirname)

    args = ctx.actions.args()
    args.add_all(include_dirs, format_each = "-i%s")
    if ctx.attr.werror:
        args.add("-E")
    args.add_all([_format_define(d) for d in ctx.attr.defines])
    args.add_all(ctx.attr.copts)
    args.add("-o", smx)
    args.add(ctx.file.src)

    ctx.actions.run(
        executable = toolchain.compiler,
        arguments = [args],
        inputs = depset(
            direct = [ctx.file.src] + ctx.files.extra_srcs,
            transitive = transitive_hdrs + transitive_srcs,
        ),
        outputs = [smx],
        mnemonic = "SpcompCompile",
        progress_message = "Compiling SourcePawn plugin %{label}",
        env = {"SOURCE_DATE_EPOCH": _BUILD_DATE_EPOCH},
    )

    return [
        DefaultInfo(files = depset([smx])),
        package_files_info("addons/sourcemod/plugins", [smx], mode = "0644"),
    ]

sourcemod_plugin = rule(
    implementation = _sourcemod_plugin_impl,
    doc = "Compiles a SourcePawn (.sp) source file into a .smx plugin.",
    attrs = {
        "copts": attr.string_list(
            doc = "Additional flags passed to `spcomp` (e.g. `[\"-w234\"]`).",
        ),
        "defines": attr.string_list(
            doc = "Preprocessor defines (`\"SYM\"` -> `SYM=1`, or `\"SYM=VAL\"`).",
        ),
        "deps": attr.label_list(
            doc = "Targets providing `SourcePawnInfo` (`sourcemod_library` or `sourcemod_extension` with `pawn_hdrs`).",
            providers = [SourcePawnInfo],
        ),
        "extra_srcs": attr.label_list(
            doc = "Additional .sp/.inc files `#include`d by relative path without adding `-i` dirs.",
            allow_files = [".sp", ".inc"],
        ),
        "includes": attr.label_list(
            doc = "Targets providing additional .inc files on the include path.",
            allow_files = [".inc"],
        ),
        "plugin_name": attr.string(
            doc = "Basename of the generated .smx (defaults to target name).",
        ),
        "src": attr.label(
            doc = "The .sp source file to compile.",
            allow_single_file = [".sp"],
            mandatory = True,
        ),
        "werror": attr.bool(
            default = True,
            doc = "Whether to pass `-E` (treat warnings as errors).",
        ),
    },
    toolchains = ["//spcomp:toolchain_type"],
    provides = [PackageFilesInfo],
)
