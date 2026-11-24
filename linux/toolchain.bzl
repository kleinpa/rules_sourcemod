"""Hermetic Linux C++ toolchains: pinned LLVM + Debian bullseye sysroots.

Targets `linux_x86_64` and `linux_x86_32` from a Linux x86_64 host. Linked
binaries reference at most glibc 2.31 / GLIBCXX_3.4.28, so they load in any
runtime image from Debian 11 / Ubuntu 20.04 / Steam Runtime sniper onward,
whatever distro did the build.

`//linux:BUILD.bazel` declares the `toolchain()` targets; this repo (only
fetched once one of them is selected) holds LLVM and the `cc_toolchain`s.
"""

# buildifier: disable=bzl-visibility
load("@rules_cc//cc/private/toolchain:unix_cc_toolchain_config.bzl", "cc_toolchain_config")
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")

# Same release as //windows:toolchain.bzl, so the repository cache downloads it once.
_LLVM_VERSION = "23.1.6"
_LLVM_MAJOR = _LLVM_VERSION.split(".")[0]
_LLVM_URL = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{ver}/LLVM-{ver}-Linux-X64.tar.xz".format(ver = _LLVM_VERSION)
_LLVM_SHA256 = "bd4d1c434ff69ef06d19e7934c04708da677e5f2eb51f5bcf052ab91818f0094"
_LLVM_STRIP_PREFIX = "LLVM-{}-Linux-X64".format(_LLVM_VERSION)

_TOOL_PATHS = {
    "ar": "bin/llvm-ar",
    "cpp": "bin/clang-cpp",
    "dwp": "bin/llvm-dwp",
    "gcc": "bin/clang",
    "gcov": "bin/llvm-cov",
    "ld": "bin/ld.lld",
    "llvm-cov": "bin/llvm-cov",
    "llvm-profdata": "bin/llvm-profdata",
    "nm": "bin/llvm-nm",
    "objcopy": "bin/llvm-objcopy",
    "objdump": "bin/llvm-objdump",
    "strip": "bin/llvm-strip",
}

def _linux_clang_toolchain(name, cpu, triple, llvm_root, sysroot):
    sysroot_path = sysroot.workspace_root
    target_flags = [
        "--target=" + triple,
        "--sysroot=" + sysroot_path,
        "-no-canonical-prefixes",
    ]
    cc_toolchain_config(
        name = name + "_config",
        cpu = cpu,
        compiler = "clang",
        toolchain_identifier = "clang-" + triple,
        host_system_name = "x86_64-unknown-linux-gnu",
        target_system_name = triple,
        target_libc = "glibc_2.31",
        abi_version = "clang",
        abi_libc_version = "glibc_2.31",
        cxx_builtin_include_directories = [
            "%workspace%/{}/lib/clang/{}/include".format(llvm_root, _LLVM_MAJOR),
            "%workspace%/{}/usr/include".format(sysroot_path),
        ],
        tool_paths = _TOOL_PATHS,
        compile_flags = target_flags + [
            "-fstack-protector",
            "-Wall",
            "-fno-omit-frame-pointer",
            # private/flags.bzl's warning list is GCC-flavoured.
            "-Wno-unknown-warning-option",
        ],
        dbg_compile_flags = ["-g"],
        opt_compile_flags = [
            "-g0",
            "-O2",
            "-D_FORTIFY_SOURCE=1",
            "-DNDEBUG",
            "-ffunction-sections",
            "-fdata-sections",
        ],
        cxx_flags = ["-std=c++17"],
        unfiltered_compile_flags = [
            "-Wno-builtin-macro-redefined",
            "-D__DATE__=\"redacted\"",
            "-D__TIMESTAMP__=\"redacted\"",
            "-D__TIME__=\"redacted\"",
        ],
        link_flags = target_flags + [
            "-fuse-ld=lld",
            "-Wl,-no-as-needed",
            "-Wl,-z,relro,-z,now",
        ],
        link_libs = [
            "-Wl,--push-state,-as-needed",
            "-lstdc++",
            "-Wl,--pop-state",
            "-Wl,--push-state,-as-needed",
            "-lm",
            "-Wl,--pop-state",
        ],
        opt_link_flags = ["-Wl,--gc-sections"],
    )

    native.filegroup(
        name = name + "_compiler_files",
        srcs = [":clang", str(sysroot)],
    )
    native.filegroup(
        name = name + "_linker_files",
        srcs = [":clang", ":lld", str(sysroot)],
    )
    native.filegroup(
        name = name + "_all_files",
        srcs = [":" + name + "_compiler_files", ":" + name + "_linker_files", ":binutils"],
    )

    cc_toolchain(
        name = name,
        all_files = ":" + name + "_all_files",
        ar_files = ":binutils",
        as_files = ":" + name + "_compiler_files",
        compiler_files = ":" + name + "_compiler_files",
        dwp_files = ":binutils",
        linker_files = ":" + name + "_linker_files",
        objcopy_files = ":binutils",
        strip_files = ":binutils",
        supports_param_files = True,
        toolchain_config = ":" + name + "_config",
    )

def linux_clang_toolchains(llvm_root, sysroot_x86_64, sysroot_x86_32):
    """Declares `cc-clang-x86_64-linux` and `cc-clang-x86_32-linux` in the LLVM repo.

    Args:
      llvm_root: Execroot-relative path of this LLVM repository.
      sysroot_x86_64: Label of the amd64 sysroot filegroup.
      sysroot_x86_32: Label of the i386 sysroot filegroup.
    """
    native.filegroup(
        name = "clang",
        srcs = native.glob(["bin/clang*", "lib/clang/**"]),
    )
    native.filegroup(
        name = "lld",
        srcs = native.glob(["bin/lld", "bin/ld.lld"]),
    )
    native.filegroup(
        name = "binutils",
        srcs = native.glob(["bin/llvm-*"]),
    )
    _linux_clang_toolchain(
        name = "cc-clang-x86_64-linux",
        cpu = "k8",
        triple = "x86_64-linux-gnu",
        llvm_root = llvm_root,
        sysroot = Label(sysroot_x86_64),
    )
    _linux_clang_toolchain(
        name = "cc-clang-x86_32-linux",
        cpu = "x86_32",
        triple = "i686-linux-gnu",
        llvm_root = llvm_root,
        sysroot = Label(sysroot_x86_32),
    )

def _llvm_linux_impl(rctx):
    if rctx.os.name != "linux":
        fail("{}: the hermetic Linux toolchain needs a Linux x86_64 host".format(rctx.name))
    rctx.download_and_extract(
        url = _LLVM_URL,
        sha256 = _LLVM_SHA256,
        stripPrefix = _LLVM_STRIP_PREFIX,
    )
    rctx.file("BUILD.bazel", """load("@rules_sourcemod//linux:toolchain.bzl", "linux_clang_toolchains")

package(default_visibility = ["//visibility:public"])

linux_clang_toolchains(
    llvm_root = {llvm_root},
    sysroot_x86_64 = {sysroot_x86_64},
    sysroot_x86_32 = {sysroot_x86_32},
)
""".format(
        llvm_root = repr(Label("@@" + rctx.name + "//:BUILD.bazel").workspace_root),
        sysroot_x86_64 = repr(str(rctx.attr.sysroot_x86_64)),
        sysroot_x86_32 = repr(str(rctx.attr.sysroot_x86_32)),
    ))

llvm_linux = repository_rule(
    implementation = _llvm_linux_impl,
    doc = "Fetches Linux x86_64 LLVM and declares clang/lld cc_toolchains for linux_x86_64 and linux_x86_32.",
    attrs = {
        "sysroot_x86_32": attr.label(mandatory = True),
        "sysroot_x86_64": attr.label(mandatory = True),
    },
)
