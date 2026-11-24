"""Asserts shipped Linux binaries need no glibc/libstdc++ newer than the sysroot's.

With the hermetic toolchain (//linux) that is Debian bullseye: glibc 2.31 and
GCC 10's GLIBCXX_3.4.28. A host toolchain on a newer distro fails this test,
which is the point: those binaries won't load in older server images.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")

# Prints the highest `<prefix>_<version>` symbol version any of $libs needs.
_MAX_VERSION = (
    "objdump -T $$libs | grep -o '{prefix}_[0-9.]*' | sed 's/{prefix}_//' | " +
    "sort -uV | tail -n1"
)

def glibc_floor_test(name, srcs, glibc = "2.31", glibcxx = "3.4.28"):
    """Checks every `.so` among `srcs` (e.g. a whole game-server preset)."""
    check = name + "_versions"
    native.genrule(
        name = check,
        srcs = srcs,
        outs = [check + ".txt"],
        cmd = (
            "libs=$$(printf '%s\\n' $(SRCS) | grep '\\.so$$') && " +
            "glibc=$$({glibc_max}) && glibcxx=$$({glibcxx_max}) && " +
            'echo "GLIBC_$$glibc GLIBCXX_$$glibcxx" > $@ && ' +
            'newer() {{ [ -n "$$2" ] && [ "$$(printf \'%s\\n\' $$1 $$2 | sort -V | tail -n1)" != "$$1" ]; }} && ' +
            'if newer {glibc} "$$glibc" || newer {glibcxx} "$$glibcxx"; then ' +
            'echo "needs GLIBC_$$glibc / GLIBCXX_$$glibcxx; floor is GLIBC_{glibc} / GLIBCXX_{glibcxx}" >&2 && ' +
            "objdump -T $$libs | grep -oE 'GLIBC(XX)?_[0-9.]+\\)? +[^ ]+$$' | sort -uV | tail -n20 >&2 && exit 1; fi"
        ).format(
            glibc = glibc,
            glibcxx = glibcxx,
            glibc_max = _MAX_VERSION.format(prefix = "GLIBC"),
            glibcxx_max = _MAX_VERSION.format(prefix = "GLIBCXX"),
        ),
        target_compatible_with = ["@platforms//os:linux"],
        testonly = True,
    )
    build_test(
        name = name,
        targets = [":" + check],
    )
