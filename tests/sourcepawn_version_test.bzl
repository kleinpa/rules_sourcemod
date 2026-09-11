"""Tests for the two compilers a `sourcemod_plugin` can be built with.

SourcePawn 2 ships two compilers -- spcomp, which emits 2.0 bytecode, and
oldspcomp, the frozen pre-2.0 one -- and the server's VM runs both generations
side by side, choosing per .smx from its header. `sourcepawn_version` on
sourcemod_plugin picks between them per plugin. Two things can go wrong there
and neither is visible from a successful build alone: the attribute could
silently run the wrong compiler, and the compiler could emit the wrong
generation of bytecode. So this checks both ends: which executable the action
runs (analysis time), and what version the .smx it produces declares
(execution time), read straight out of the file header.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

# The compiler a plugin is expected to have been built with, keyed by
# sourcepawn_version. Basenames only, so the Windows `.exe` suffix does not
# matter -- and prefix-matched below, for the same reason.
_COMPILER_BASENAME = {
    "1": "oldspcomp",
    "2": "spcomp",
}

# The `version` field of the .smx header (sp_file_hdr_t in smx-headers.h): a
# little-endian uint16 at offset 4, just after the FFPS magic. The 2.0
# compiler writes SP_VERSION_2 (0x0200); the legacy one writes a 1.x version,
# 0x0102 today, though only the major byte is asserted on since the minor has
# moved before and would again if upstream touched the frozen compiler.
_SMX_VERSION_CHECK = {
    "1": "[ \"$${v#* }\" = 01 ]",
    "2": "[ \"$$v\" = \"00 02\" ]",
}

def _plugin_compiler_test_impl(ctx):
    env = analysistest.begin(ctx)

    actions = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == "SpcompCompile"
    ]
    asserts.equals(env, 1, len(actions), "expected exactly one SpcompCompile action")

    # argv[0] is the compiler; everything after it is the plugin's flags.
    compiler = actions[0].argv[0].split("/")[-1]
    expected = _COMPILER_BASENAME[ctx.attr.sourcepawn_version]
    asserts.true(
        env,
        compiler.startswith(expected),
        "sourcepawn_version = \"{}\" should compile with {}, got {}".format(
            ctx.attr.sourcepawn_version,
            expected,
            compiler,
        ),
    )

    return analysistest.end(env)

plugin_compiler_test = analysistest.make(
    _plugin_compiler_test_impl,
    attrs = {
        "sourcepawn_version": attr.string(
            doc = "The sourcepawn_version the target under test was declared with.",
            mandatory = True,
            values = ["1", "2"],
        ),
    },
)

def smx_version_test(name, plugin, sourcepawn_version):
    """Asserts that `plugin`'s .smx header declares the expected bytecode generation.

    A genrule does the check rather than a test rule, so this needs no test
    runner beyond the shell every genrule in this repo already assumes: the
    check failing fails the genrule, and the build_test turns that into a test
    result.
    """
    check = name + "_smx_header"
    native.genrule(
        name = check,
        srcs = [plugin],
        outs = [check + ".txt"],
        cmd = (
            "v=$$(od -An -tx1 -j4 -N2 $(location {plugin}) | tr -s ' ' | sed 's/^ //;s/ $$//') && " +
            "if ! {check}; then " +
            "echo \"{plugin}: .smx header version bytes '$$v' are not SourcePawn {version}\" >&2; exit 1; " +
            "fi && echo \"$$v\" > $@"
        ).format(
            plugin = plugin,
            check = _SMX_VERSION_CHECK[sourcepawn_version],
            version = sourcepawn_version,
        ),
        testonly = True,
    )
    build_test(
        name = name,
        targets = [":" + check],
    )
