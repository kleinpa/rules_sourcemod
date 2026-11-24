"""Fetches a normalized Windows SDK + MSVC CRT sysroot via xwin."""

_XWIN_VERSION = "0.10.0"
_XWIN_URL = "https://github.com/Jake-Shadle/xwin/releases/download/{version}/xwin-{version}-x86_64-unknown-linux-musl.tar.gz"
_XWIN_SHA256 = "d870eb4b2f390878af6da1ccd3cf321d22fcb72720984853b4be732ae597fc88"

# Pinned explicitly so `xwin splat` does not track Microsoft's moving "latest"
# manifest and produce different SDK/CRT bits across machines or cache evictions.
_SDK_VERSION = "10.0.26100"
_CRT_VERSION = "14.44.17.14"

def _xwin_sysroot_impl(rctx):
    if not rctx.attr.accept_license:
        fail(("{name}: accept_license must be set to True to acknowledge the " +
              "Microsoft Windows SDK and MSVC++ Runtime license terms " +
              "(https://github.com/Jake-Shadle/xwin#license).").format(name = rctx.name))

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

    result = rctx.execute(
        [
            rctx.path("xwin_bin/xwin"),
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
        ],
        timeout = rctx.attr.timeout,
        quiet = False,
    )
    if result.return_code != 0:
        fail("xwin splat failed (exit {}):\n{}\n{}".format(result.return_code, result.stdout, result.stderr))

    # Flatten versioned subdirectories and remove the space in "Windows Kits"
    # so explicit /imsvc and /libpath: flags have stable, space-free paths
    # (clang-cl's `/winsysroot:` mis-joins versioned subpaths, and its flag
    # parser splits `/imsvc` and `/libpath:` arguments on embedded spaces).
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
        fail("Normalizing xwin sysroot failed:\n" + result.stdout + result.stderr)

xwin_sysroot = repository_rule(
    implementation = _xwin_sysroot_impl,
    attrs = {
        "accept_license": attr.bool(
            mandatory = True,
            doc = "Must be True to accept the Microsoft Windows SDK and MSVC++ Runtime license (https://github.com/Jake-Shadle/xwin#license).",
        ),
        "arch": attr.string(
            default = "x86",
            values = ["x86"],
            doc = "Target architecture forwarded to xwin --arch.",
        ),
        "timeout": attr.int(
            default = 1800,
            doc = "Timeout in seconds for xwin download + splat.",
        ),
    },
    doc = "Fetches a Windows SDK + MSVC CRT sysroot via xwin and normalizes it to version-free paths (`VC/Tools/MSVC/{include,lib/<arch>}` and `WindowsKits/{Include,Lib}/{ucrt,um,shared}[/<arch>]`).",
)
