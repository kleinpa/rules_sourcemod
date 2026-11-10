"""Test that the self-contained SourceMod libraries resolve all their symbols.

A shared object links with undefined symbols left in it, so a missing source
file is not a build error -- it is a `dlopen` error on the game server, which
is the last place anyone wants to find it. That is how a missing
`core/logic/PseudoAddrManager.cpp` surfaced: every target built, CI was green,
and srcds reported `[META] Failed to load plugin
addons/sourcemod/bin/sourcemod_mm` and came up with no SourceMod at all.

`sourcemod.logic.so` and the loader are the two libraries this can be checked
on without starting a game: neither links against the HL2SDK or the engine, so
every symbol they reference must be satisfied by themselves or by the
libraries they record in DT_NEEDED. Everything else (core, sdktools, the game
extension) legitimately leaves engine symbols to be resolved by srcds at load
time, and has nothing to compare against short of running it.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")

# `nm -D` reads the dynamic symbol table, which is the one the loader uses.
# Only type `U` is required: `w` is a weak reference that resolves to zero if
# nothing provides it (__gmon_start__, the _ITM_* transactional-memory hooks),
# which is not a failure. Symbol versions are stripped from both sides, since
# a reference spells them `name@VER` and a definition `name@@VER`.
_PROVIDED = (
    'nm -D --defined-only "$$lib" | sed "s/.* //"; ' +
    'for dep in $$(ldd "$$lib" | sed -n "s/.*=> \\(\\/[^ ]*\\) .*/\\1/p"); do ' +
    'nm -D --defined-only "$$dep" 2>/dev/null | sed "s/.* //"; ' +
    "done"
)

_REFERENCED = 'nm -D --undefined-only "$$lib" | sed -n "s/^ *U //p"'

def symbol_closure_test(name, lib):
    """Asserts every symbol `lib` references is one it or its DT_NEEDED provide.

    A genrule does the check rather than a test rule, for the same reason
    //tests:smx_version_test.bzl does: it needs no test runner beyond the shell
    every genrule here already assumes, and the build_test turns a failing
    check into a test result.
    """
    check = name + "_symbols"
    native.genrule(
        name = check,
        srcs = [lib],
        outs = [check + ".txt"],
        cmd = (
            'lib="$(location {lib})" && ' +
            "{{ {provided}; }} | sed 's/@.*//' | sort -u > $@.provided && " +
            "{referenced} | sed 's/@.*//' | sort -u > $@.referenced && " +
            "unresolved=$$(comm -23 $@.referenced $@.provided) && " +
            'if [ -n "$$unresolved" ]; then ' +
            'echo "{lib}: references symbols nothing provides, so it will fail to dlopen:" >&2 && ' +
            'echo "$$unresolved" >&2 && exit 1; ' +
            "fi && " +
            'echo "$$(wc -l < $@.referenced) references, all resolved" > $@'
        ).format(
            lib = lib,
            provided = _PROVIDED,
            referenced = _REFERENCED,
        ),
        # nm and ldd are binutils/glibc, and the DT_NEEDED walk is ELF.
        target_compatible_with = ["@platforms//os:linux"],
        testonly = True,
    )
    build_test(
        name = name,
        targets = [":" + check],
    )
