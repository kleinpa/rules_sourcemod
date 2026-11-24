"""Debian bullseye sysroots (glibc 2.31, GCC 10 libstdc++) for the hermetic Linux toolchain.

Only the C/C++ runtime goes here: anything else a build needs (zlib, PCRE,
SQLite, ...) is vendored. To bump, pick a new snapshot timestamp and take each
package's `Filename` and `SHA256` from
`<_SNAPSHOT>/dists/bullseye/main/binary-<arch>/Packages.xz`. The floor is the
point, so this should rarely move.
"""

_SNAPSHOT = "https://snapshot.debian.org/archive/debian/20251101T000000Z"

_DEBS = {
    "amd64": [
        ("pool/main/g/glibc/libc6_2.31-13+deb11u11_amd64.deb", "05f7264da867b37f4c5ce49266b558ea1e81e05a9464f623152fca70f3550282"),
        ("pool/main/g/glibc/libc6-dev_2.31-13+deb11u11_amd64.deb", "e7f7b45d9c5cfcf37609f0b6efd3c645272c812144703af89dfd32218fcb0fd3"),
        ("pool/main/libx/libxcrypt/libcrypt1_4.4.18-4_amd64.deb", "f617952df0c57b4ee039448e3941bccd3f97bfff71e9b0f87ca6dae15cb3f5ef"),
        ("pool/main/libx/libxcrypt/libcrypt-dev_4.4.18-4_amd64.deb", "8b04bf00b8c43360d9ba3adec209db290168ba3526d4aef3175fb84372b1bebf"),
        ("pool/main/l/linux/linux-libc-dev_5.10.223-1_amd64.deb", "e3be603bd12377bb90fcfb0f2048ca3a81c886e49d6f09945b82159d1c54f7b2"),
        ("pool/main/g/gcc-10/libgcc-s1_10.2.1-6_amd64.deb", "e478f2709d8474165bb664de42e16950c391f30eaa55bc9b3573281d83a29daf"),
        ("pool/main/g/gcc-10/libgcc-10-dev_10.2.1-6_amd64.deb", "3b711374092b84e732c4e73cf33e02cff02e34a5f105eb6467de8d9038e4cd9d"),
        ("pool/main/g/gcc-10/libstdc++6_10.2.1-6_amd64.deb", "5c155c58935870bf3b4bfe769116841c0d286a74f59eccfd5645693ac23f06b1"),
        ("pool/main/g/gcc-10/libstdc++-10-dev_10.2.1-6_amd64.deb", "20b1f56863dcc5f187d6cb53b2aa6149bd013be4ec67e10c2c31a22fda619a01"),
    ],
    "i386": [
        ("pool/main/g/glibc/libc6_2.31-13+deb11u11_i386.deb", "8198abd817cbcd615ce3207fb924317b53cc0b522bfe57d689757de13fe00d66"),
        ("pool/main/g/glibc/libc6-dev_2.31-13+deb11u11_i386.deb", "7d10b944894d2b6ccab08ccf51aae6cef6c5f5773f36696e6d9f34c21e0365b4"),
        ("pool/main/libx/libxcrypt/libcrypt1_4.4.18-4_i386.deb", "202217d6ca6ddf9ee5e13ad6b96feef1b3cbc8b2e0282f87883ae50a9f7325f7"),
        ("pool/main/libx/libxcrypt/libcrypt-dev_4.4.18-4_i386.deb", "ea0ba21b3bacbf8cd15cbefd17c224cf2298bb4f0af0992d32bf2e3b6847b70c"),
        ("pool/main/l/linux/linux-libc-dev_5.10.223-1_i386.deb", "e57d6065a43e763e54a0a80afd66fa2371bcdc3b035f9f4463816e9c6fc26049"),
        ("pool/main/g/gcc-10/libgcc-s1_10.2.1-6_i386.deb", "0a52edec5d626f8d9acf1998248d276760aff3950f44a308d27d4a2a488fe18d"),
        ("pool/main/g/gcc-10/libgcc-10-dev_10.2.1-6_i386.deb", "64a544dcf5463225603cb025a05c7b79dea9876004c09d81af2bc31ffe0ccc1e"),
        ("pool/main/g/gcc-10/libstdc++6_10.2.1-6_i386.deb", "ef9b1f03163ad32c8f940b9a9e417773ff3d2f08ad2044d9c28fed5b81de3b7e"),
        ("pool/main/g/gcc-10/libstdc++-10-dev_10.2.1-6_i386.deb", "4b629a2acb5e19cc0c7bf2a39f7ab7c268f977ce07e78ad9853648da93868d40"),
    ],
}

# Debian's absolute symlinks (usr/lib/<triple>/libm.so -> /lib/<triple>/libm.so.6)
# are rewritten relative so the tree works wherever Bazel puts it (Bazel's own tar
# extraction re-roots them under this repo's absolute path, which is just as
# unportable). Anything left dangling, and everything that isn't headers,
# libraries, or CRT objects, is dropped.
_NORMALIZE = """
set -eu
root=$(pwd -P)
find . -type l | while read -r link; do
  target=$(readlink "$link")
  case "$target" in
    "$root"/*) target=${target#"$root"} ;;
    /*) ;;
    *) continue ;;
  esac
  ln -sfn "$(realpath -m --relative-to="$(dirname "$link")" ".$target")" "$link"
done
rm -rf etc sbin usr/bin usr/sbin usr/share var usr/lib/*/gconv
find . -xtype l -delete
"""

def _linux_sysroot_impl(rctx):
    for i, (path, sha256) in enumerate(_DEBS[rctx.attr.arch]):
        deb = "_debs/{}".format(i)
        rctx.download_and_extract(url = _SNAPSHOT + "/" + path, sha256 = sha256, output = deb, type = "deb")
        data = [e for e in rctx.path(deb).readdir() if e.basename.startswith("data.tar")]
        if len(data) != 1:
            fail("{}: expected one data.tar.* in {}".format(rctx.name, path))
        rctx.extract(data[0])
    rctx.delete("_debs")

    result = rctx.execute(["sh", "-c", _NORMALIZE])
    if result.return_code != 0:
        fail("{}: normalizing sysroot failed:\n{}{}".format(rctx.name, result.stdout, result.stderr))

    rctx.file("BUILD.bazel", """filegroup(
    name = "sysroot",
    srcs = glob(["**"], exclude = ["BUILD.bazel", "REPO.bazel"]),
    visibility = ["//visibility:public"],
)
""")
    return rctx.repo_metadata(reproducible = True)

linux_sysroot = repository_rule(
    implementation = _linux_sysroot_impl,
    doc = "Assembles a relocatable Debian bullseye sysroot for one architecture.",
    attrs = {
        "arch": attr.string(mandatory = True, values = ["amd64", "i386"]),
    },
)
