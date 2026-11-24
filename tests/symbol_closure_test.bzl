"""Asserts that self-contained shared libraries (loader, logic) have no unresolved symbols."""

load("@bazel_skylib//rules:build_test.bzl", "build_test")

_PROVIDED = (
    'nm -D --defined-only "$$lib" | sed "s/.* //"; ' +
    'for dep in $$(ldd "$$lib" | sed -n "s/.*=> \\(\\/[^ ]*\\) .*/\\1/p"); do ' +
    'nm -D --defined-only "$$dep" 2>/dev/null | sed "s/.* //"; ' +
    "done"
)

_REFERENCED = 'nm -D --undefined-only "$$lib" | sed -n "s/^ *U //p"'

def symbol_closure_test(name, lib):
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
            'echo "{lib}: unresolved symbols:" >&2 && ' +
            'echo "$$unresolved" >&2 && exit 1; ' +
            "fi && " +
            'echo "$$(wc -l < $@.referenced) references, all resolved" > $@'
        ).format(
            lib = lib,
            provided = _PROVIDED,
            referenced = _REFERENCED,
        ),
        target_compatible_with = ["@platforms//os:linux"],
        testonly = True,
    )
    build_test(
        name = name,
        targets = [":" + check],
    )
