_XWIN_VERSION = "0.10.0"
_XWIN_URL = "https://github.com/Jake-Shadle/xwin/releases/download/{version}/xwin-{version}-x86_64-unknown-linux-musl.tar.gz"
_XWIN_SHA256 = "d870eb4b2f390878af6da1ccd3cf321d22fcb72720984853b4be732ae597fc88"

# Without these, `xwin splat` silently resolves to whichever SDK/CRT release
# Microsoft's manifest currently calls latest -- unlike every other input to
# this toolchain (xwin itself and the LLVM release above are both pinned by
# exact version + sha256), that fetch was never actually pinned, so two
# machines (or the same machine at two different times) can get genuinely
# different MSVC CRT/Windows SDK bits for identical source. That is not a
# theoretical gap: it produced a real miscompiled metamod.2.ep1.dll (the one
# thing in this pipeline still built from source, not fetched prebuilt) --
# a from-scratch CI fetch landed on a newer SDK/CRT than a long-lived local
# Bazel repository cache had, and only the CI-built binary crashed on boot.
# These are the versions the known-good (non-crashing) build was compiled
# against; bump deliberately, not by way of an unrelated cache eviction.
_SDK_VERSION = "10.0.26100"
_CRT_VERSION = "14.44.17.14"

def _xwin_sysroot_impl(rctx):
    if not rctx.attr.accept_license:
        fail(("{name}: accept_license must be set to True. This downloads the " +
              "Microsoft Windows SDK and MSVC++ Runtime under Microsoft's own " +
              "distribution terms -- see https://github.com/Jake-Shadle/xwin#license " +
              "-- so it requires an explicit, visible opt-in rather than a " +
              "default.").format(name = rctx.name))

    rctx.download_and_extract(
        url = _XWIN_URL.format(version = _XWIN_VERSION),
        sha256 = _XWIN_SHA256,
        stripPrefix = "xwin-{}-x86_64-unknown-linux-musl".format(_XWIN_VERSION),
        output = "xwin_bin",
    )

    rctx.file(
        "sysroot/BUILD.bazel",
        """filegroup(
    name = "sysroot",
    srcs = ["."],
    visibility = ["//visibility:public"],
)
""",
    )

    xwin = rctx.path("xwin_bin/xwin")
    args = [
        xwin,
        "--accept-license",
        "--arch",
        rctx.attr.arch,
        "--sdk-version",
        _SDK_VERSION,
        "--crt-version",
        _CRT_VERSION,
        "splat",
        "--use-winsysroot-style",
        "--preserve-ms-arch-notation",
        "--output",
        "sysroot",
    ]
    result = rctx.execute(args, timeout = rctx.attr.timeout, quiet = False)
    if result.return_code != 0:
        fail("xwin splat failed (exit {}):\n{}\n{}".format(result.return_code, result.stdout, result.stderr))

    # Collapse the version-numbered VC tools / Windows SDK directories xwin
    # produces (e.g. "VC/Tools/MSVC/14.44.17.14/...", which changes every time
    # xwin fetches an updated toolset) down to fixed, version-free paths:
    #   sysroot/VC/Tools/MSVC/{include,lib/<arch>}
    #   sysroot/WindowsKits/{Include,Lib}/{ucrt,um,shared}[/<arch>]
    # cc_toolchain_config.bzl's Windows branch (in the toolchains_llvm patch)
    # references these fixed paths directly with explicit /imsvc and
    # /libpath: flags, rather than clang-cl's `/winsysroot:` auto-detection --
    # which, at least as of LLVM 18, mis-joins the versioned subdirectory it
    # detects into isystem paths with a stray leading `:` (observed directly:
    # `-internal-isystem :<root>/VC/Tools/MSVC/include` reported as
    # "nonexistent" even though the directory exists), silently losing every
    # sysroot header/lib path it was supposed to add.
    #
    # "Windows Kits" (xwin's own directory name) is renamed to "WindowsKits"
    # here too: clang-cl's own command-line tokenizer re-splits a `/imsvc<path>`
    # or `/libpath:<path>` argument on embedded spaces even when Bazel passes
    # it as a single argv element, silently truncating the path and turning
    # the rest into a stray extra "source file"/"linker input" argument.
    # Dropping the space is simpler and more robust than trying to get
    # internal quoting right across Starlark/argv/clang-cl's parser.
    collapse_script = """
set -eu
cd sysroot
vcver=$(ls "VC/Tools/MSVC")
for d in "VC/Tools/MSVC/$vcver"/*; do mv "$d" "VC/Tools/MSVC/"; done
rmdir "VC/Tools/MSVC/$vcver"
mv "Windows Kits" WindowsKits
sdkver=$(ls "WindowsKits/10/Include")
mkdir -p "WindowsKits/Include" "WindowsKits/Lib"
for d in "WindowsKits/10/Include/$sdkver"/*; do mv "$d" "WindowsKits/Include/"; done
for d in "WindowsKits/10/Lib/$sdkver"/*; do mv "$d" "WindowsKits/Lib/"; done
rm -rf "WindowsKits/10"
"""
    result = rctx.execute(["sh", "-c", collapse_script])
    if result.return_code != 0:
        fail("Normalizing the xwin sysroot layout failed:\n" + result.stdout + result.stderr)

xwin_sysroot = repository_rule(
    implementation = _xwin_sysroot_impl,
    attrs = {
        "accept_license": attr.bool(
            mandatory = True,
            doc = "Must be explicitly set to True to confirm acceptance of the Microsoft Windows SDK and MSVC++ Runtime EULA that xwin downloads under. See https://github.com/Jake-Shadle/xwin#license.",
        ),
        "arch": attr.string(
            default = "x86",
            values = ["x86", "x86_64", "aarch", "aarch64"],
            doc = "Target architecture(s) to fetch, forwarded to xwin's --arch.",
        ),
        "timeout": attr.int(
            default = 1800,
            doc = "Timeout in seconds for the xwin download+splat, which pulls the Windows SDK and MSVC CRT from Microsoft's CDN.",
        ),
    },
    doc = """\
Fetches a Windows SDK + MSVC CRT sysroot via xwin (github.com/Jake-Shadle/xwin)
and normalizes it to the fixed, version-directory-free layout that this
repo's toolchains_llvm patch (patches/toolchains_llvm-windows-i686.patch)
expects: `VC/Tools/MSVC/{include,lib/<arch>}` and
`WindowsKits/{Include,Lib}/{ucrt,um,shared}[/<arch>]`. Exposes it as
`@<name>//sysroot:sysroot`.

Downloads Microsoft's own SDK/CRT packages under Microsoft's distribution
terms; `accept_license = True` is required to acknowledge this. See
https://github.com/Jake-Shadle/xwin#license.
""",
)
