"""`sourcemod_plugin` — compiles a SourcePawn source file into a .smx plugin."""

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")
load("//sourcemod:build_date.bzl", "BUILD_DATE_EPOCH")
load("//sourcemod:providers.bzl", "SourceModPackageInfo", "package_providers")

def _sourcemod_plugin_impl(ctx):
    toolchain = ctx.toolchains["//spcomp:toolchain_type"].spcomp

    if ctx.attr.sourcepawn_version == "1":
        compiler = toolchain.legacy_compiler
        if not compiler:
            fail("{}: sourcepawn_version = \"1\" needs a legacy compiler, and the ".format(ctx.label) +
                 "registered spcomp toolchain does not provide one (see " +
                 "`legacy_compiler` on spcomp_toolchain)")
    else:
        compiler = toolchain.compiler

    plugin_name = ctx.attr.plugin_name or ctx.label.name
    smx = ctx.actions.declare_file(plugin_name + ".smx")
    dest_dir = ctx.attr.dest_dir or "addons/sourcemod/plugins"

    args = ctx.actions.args()

    # spcomp resolves includes relative to its own location unless told
    # otherwise, which breaks under Bazel's sandbox. Derive the stdlib include
    # directory from the actual bundled files rather than from the compiler
    # path, so it stays correct regardless of how the toolchain is laid out.
    include_dirs = []
    stdlib_files = toolchain.stdlib_includes.to_list()
    if stdlib_files:
        include_dirs.append(stdlib_files[0].dirname)

    for dep in ctx.attr.includes:
        for inc in dep.files.to_list():
            if inc.dirname not in include_dirs:
                include_dirs.append(inc.dirname)
    args.add_all(include_dirs, format_each = "-i%s")

    # Treat warnings as errors: a plugin that compiles with warnings is almost
    # always a latent runtime bug, and the old build silently ignored them.
    if ctx.attr.werror:
        args.add("-E")

    for define in ctx.attr.defines:
        args.add(define)

    args.add("-o", smx)
    args.add(ctx.file.src)

    # extra_srcs are made available to the sandbox but never named on the
    # command line: a plugin split across several files pulls them in with
    # `#include "subdir/part.sp"`, which spcomp resolves relative to the
    # including file. They only have to exist at the right relative path.
    inputs = depset(
        direct = [ctx.file.src],
        transitive = [
            toolchain.stdlib_includes,
            depset([f for dep in ctx.attr.includes for f in dep.files.to_list()]),
            depset(ctx.files.extra_srcs),
        ],
    )

    ctx.actions.run(
        executable = compiler,
        arguments = [args],
        inputs = inputs,
        outputs = [smx],
        mnemonic = "SpcompCompile",
        progress_message = "Compiling SourcePawn plugin %{label}",
        # Both compilers read the wall clock and inject the result as
        # SourcePawn's __DATE__/__TIME__, which plugins/include/core.inc copies
        # into every plugin's `__version` struct -- so without this, two builds
        # of the same .sp produce different .smx files and every cached plugin
        # expires at midnight. The compilers //sourcemod:patches teaches
        # SOURCE_DATE_EPOCH are the ones this module's toolchain registers; a
        # consumer who registers unpatched ones of their own simply gets
        # upstream's behaviour back.
        env = {"SOURCE_DATE_EPOCH": BUILD_DATE_EPOCH},
        # Beyond the clock read above, the compilers write intermediates next
        # to their inputs and read no ambient state; caching is safe.
        execution_requirements = {"supports-workers": "0"},
    )

    return [
        DefaultInfo(files = depset([smx])),
    ] + package_providers(dest_dir, [smx])

sourcemod_plugin = rule(
    implementation = _sourcemod_plugin_impl,
    doc = """Compiles a SourcePawn (.sp) source file into a .smx plugin.

Example:

    sourcemod_plugin(
        name = "my_plugin",
        src = "my_plugin.sp",
        includes = [":my_natives_inc"],
    )

Compiled with SourcePawn 2's spcomp unless `sourcepawn_version = "1"` asks
for the pre-2.0 compiler; see that attribute.
""",
    attrs = {
        "src": attr.label(
            doc = "The .sp source file to compile.",
            allow_single_file = [".sp"],
            mandatory = True,
        ),
        "includes": attr.label_list(
            doc = "Targets providing additional .inc files on the include path.",
            allow_files = [".inc"],
        ),
        "extra_srcs": attr.label_list(
            doc = """Additional source files the plugin `#include`s by relative
path, e.g. the `subdir/part.sp` files a multi-file plugin is split across.
These are placed in the sandbox but not passed to spcomp directly.""",
            allow_files = [".sp", ".inc"],
        ),
        "defines": attr.string_list(
            doc = "Extra flags passed verbatim to spcomp (e.g. 'SOME_MACRO=1').",
        ),
        "plugin_name": attr.string(
            doc = "Basename of the generated .smx. Defaults to the target name.",
        ),
        "werror": attr.bool(
            doc = "Treat SourcePawn warnings as errors.",
            default = True,
        ),
        "sourcepawn_version": attr.string(
            doc = """Which compiler, and so which bytecode generation, the plugin
is built with. "2" (the default) is SourcePawn 2's spcomp, what SourceMod
builds its own plugins with: it takes classic source too, but under 2.0's
rules -- multi-dimensional arrays are heap-allocated reference types, VFormat()
is gone, and so on -- and defines `__sourcepawn2`. "1" is the pre-2.0 compiler
(oldspcomp) for a plugin that isn't ready for that. The server's VM runs both
generations side by side, choosing per .smx, so this is a per-plugin choice
rather than a per-server one.""",
            default = "2",
            values = ["1", "2"],
        ),
        "dest_dir": attr.string(
            doc = "Destination directory within the package (default: addons/sourcemod/plugins).",
        ),
    },
    toolchains = ["//spcomp:toolchain_type"],
    provides = [PackageFilesInfo, SourceModPackageInfo],
)
