"""Test for the bytecode generation `sourcemod_plugin` emits.

A successful build says spcomp ran, not what it wrote. The .smx header carries
the bytecode version the server's VM dispatches on, so this reads it straight
out of the file: if a SourceMod bump ever changed which generation the bundled
compiler emits, every plugin here would still build and the difference would
only show up when a server refused to load them.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")

# The `version` field of the .smx header (sp_file_hdr_t in smx-headers.h): a
# little-endian uint16 at offset 4, just after the FFPS magic. SourceMod 1.12's
# compiler writes a 1.x version, 0x0102 today; only the major byte is asserted
# on, since the minor has moved before and would again upstream.
_SMX_VERSION_CHECK = "[ \"$${v#* }\" = 01 ]"

def smx_version_test(name, plugin):
    """Asserts that `plugin`'s .smx header declares SourcePawn 1 bytecode.

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
            "echo \"{plugin}: .smx header version bytes '$$v' are not SourcePawn 1\" >&2; exit 1; " +
            "fi && echo \"$$v\" > $@"
        ).format(
            plugin = plugin,
            check = _SMX_VERSION_CHECK,
        ),
        testonly = True,
    )
    build_test(
        name = name,
        targets = [":" + check],
    )
