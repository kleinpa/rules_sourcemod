"""Trims an extracted LLVM release for the Clang toolchain repositories."""

# Everything the toolchains in //linux:toolchain.bzl and //windows:toolchain.bzl
# run, plus the binaries those names symlink to (clang-<major>, lld, llvm-ar, ...).
_BIN = [
    "clang",
    "clang-cl",
    "clang-cpp",
    "ld.lld",
    "lld",
    "lld-link",
    "llvm-ar",
    "llvm-cov",
    "llvm-dwp",
    "llvm-lib",
    "llvm-nm",
    "llvm-objcopy",
    "llvm-objdump",
    "llvm-profdata",
    "llvm-strip",
]

def prune_llvm(rctx, llvm_major):
    """Deletes all of an LLVM release but the tools in `_BIN` and clang's resource directory.

    A full release is over 11 GB, mostly flang, MLIR, and static libraries.

    Args:
      rctx: Repository context whose root holds the extracted release.
      llvm_major: LLVM major version.
    """
    keep = {
        ".": ["bin", "lib"],
        "bin": _BIN + ["clang-" + llvm_major],
        "lib": ["clang"],
    }
    for directory, names in keep.items():
        for entry in rctx.path(directory).readdir():
            if entry.basename not in names:
                rctx.delete(entry)
