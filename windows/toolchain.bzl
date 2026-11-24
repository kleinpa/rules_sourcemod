"""Self-contained Linux -> 32-bit Windows (clang-cl/lld-link) cross-toolchain.

Downloads an official Linux x86_64 LLVM release and pairs it with a normalized
xwin sysroot (see //windows:xwin_sysroot.bzl) via rules_cc's Windows toolchain
config, avoiding any dependency or root-only override on toolchains_llvm.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

# buildifier: disable=bzl-visibility
load(
    "@rules_cc//cc/private/toolchain:windows_cc_toolchain_config.bzl",
    "cc_toolchain_config",
)
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")

# Pinned to LLVM 23.1.2+ so modern MSVC STL headers pass their _EMIT_STL_ERROR
# version gate and lld-link does not dynamically link legacy libxml2.so.2.
_LLVM_VERSION = "23.1.6"
_LLVM_MAJOR = _LLVM_VERSION.split(".")[0]
_LLVM_URL = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{ver}/LLVM-{ver}-Linux-X64.tar.xz".format(ver = _LLVM_VERSION)
_LLVM_SHA256 = "bd4d1c434ff69ef06d19e7934c04708da677e5f2eb51f5bcf052ab91818f0094"
_LLVM_STRIP_PREFIX = "LLVM-{}-Linux-X64".format(_LLVM_VERSION)

def windows_clang_cl_toolchain(name, sysroot_label, sysroot_path, builtin_includes):
    """Declares the clang-cl/lld-link cc_toolchain targets for windows_x86_32.

    Args:
      name: Name of the public `toolchain()` target.
      sysroot_label: Label of the normalized xwin sysroot filegroup.
      sysroot_path: Execroot-relative directory path to the sysroot.
      builtin_includes: Builtin compiler and sysroot include directory paths.
    """
    include_flags = [
        "/imsvc" + sysroot_path + "/VC/Tools/MSVC/include",
        "/imsvc" + sysroot_path + "/WindowsKits/Include/ucrt",
        "/imsvc" + sysroot_path + "/WindowsKits/Include/um",
        "/imsvc" + sysroot_path + "/WindowsKits/Include/shared",
    ]
    lib_flags = [
        "/libpath:" + sysroot_path + "/VC/Tools/MSVC/lib/x86",
        "/libpath:" + sysroot_path + "/WindowsKits/Lib/ucrt/x86",
        "/libpath:" + sysroot_path + "/WindowsKits/Lib/um/x86",
    ]
    tool_paths = {
        "ar": "bin/llvm-lib",
        "cpp": "bin/clang-cl",
        "dwp": "bin/llvm-dwp",
        "gcc": "bin/clang-cl",
        "gcov": "bin/llvm-profdata",
        "ld": "bin/lld-link",
        "llvm-cov": "bin/llvm-cov",
        "llvm-profdata": "bin/llvm-profdata",
        "nm": "bin/llvm-nm",
        "objcopy": "bin/llvm-objcopy",
        "objdump": "bin/llvm-objdump",
        "strip": "bin/llvm-strip",
    }

    cc_toolchain_config(
        name = name + "_config",
        # rules_cc's _use_msvc_toolchain only enables MSVC artifact naming
        # (.dll/.obj/.lib) for "x64_windows" or "arm64_windows"; actual codegen
        # is governed by --target=i686-pc-windows-msvc and /MACHINE:X86 below.
        cpu = "x64_windows",
        # Reported as "msvc-cl" so @rules_cc//cc/compiler:msvc-cl selects match.
        compiler = "msvc-cl",
        toolchain_identifier = "clang-cl-x86_32-windows",
        host_system_name = "x86_64",
        target_system_name = "i686-pc-windows-msvc",
        target_libc = "msvc",
        abi_version = "local",
        abi_libc_version = "local",
        cxx_builtin_include_directories = builtin_includes,
        tool_paths = tool_paths,
        archiver_flags = ["/MACHINE:X86"] + lib_flags,
        default_link_flags = ["/MACHINE:X86", "/ignore:4099"] + lib_flags,
        default_compile_flags = [
            "--target=i686-pc-windows-msvc",
            # Match real MSVC's /W3 rather than clang-cl's cumulative /Wall.
            "/W3",
            # C++17 removed `register`, still used in SourceMod headers; kept
            # here because real cl.exe rejects -Wno-* flags with D8021.
            "-Wno-register",
            "/DWIN32",
            "/D_WIN32",
            "/D_WINDOWS",
            "/EHsc",
        ] + include_flags,
        dbg_mode_debug_flag = "/DEBUG",
        fastbuild_mode_debug_flag = "/DEBUG",
        supports_parse_showincludes = False,
        msvc_cl_path = tool_paths["gcc"],
        msvc_link_path = tool_paths["ld"],
        msvc_lib_path = tool_paths["ar"],
        msvc_env_include = sysroot_path + "/VC/Tools/MSVC/include",
        msvc_env_lib = sysroot_path + "/VC/Tools/MSVC/lib/x86",
    )

    native.filegroup(
        name = "compiler_files",
        srcs = native.glob(["bin/clang*", "lib/*.so*", "lib/clang/**"]) + [sysroot_label],
    )
    native.filegroup(
        name = "linker_files",
        srcs = native.glob(["bin/lld*", "bin/llvm-lib*", "bin/llvm-ar*", "lib/*.so*"]) + [sysroot_label],
    )
    native.filegroup(
        name = "ar_files",
        srcs = native.glob(["bin/llvm-lib*", "bin/llvm-ar*", "lib/*.so*"]),
    )
    native.filegroup(
        name = "all_files",
        srcs = [":compiler_files", ":linker_files"],
    )
    native.filegroup(name = "empty", srcs = [])

    cc_toolchain(
        name = "cc-clang-x86_32-windows",
        all_files = ":all_files",
        ar_files = ":ar_files",
        as_files = ":empty",
        compiler_files = ":compiler_files",
        dwp_files = ":empty",
        linker_files = ":linker_files",
        objcopy_files = ":empty",
        strip_files = ":empty",
        supports_header_parsing = False,
        toolchain_config = ":" + name + "_config",
    )

    native.toolchain(
        name = name,
        exec_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
        target_compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_32",
        ],
        toolchain = ":cc-clang-x86_32-windows",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        visibility = ["//visibility:public"],
    )

def _llvm_windows_toolchain_impl(rctx):
    if rctx.os.name != "linux":
        fail("{}: the clang-cl cross toolchain needs a Linux x86_64 host".format(rctx.name))

    rctx.download_and_extract(
        url = _LLVM_URL,
        sha256 = _LLVM_SHA256,
        stripPrefix = _LLVM_STRIP_PREFIX,
    )

    own_root = Label("@@" + rctx.name + "//:BUILD.bazel").workspace_root
    sysroot_label = rctx.attr.sysroot
    sysroot_path = paths.join(sysroot_label.workspace_root, sysroot_label.package)
    builtin_includes = [
        "%workspace%/" + own_root + "/lib/clang/" + _LLVM_MAJOR + "/include",
        "%workspace%/" + sysroot_path + "/VC/Tools/MSVC/include",
        "%workspace%/" + sysroot_path + "/WindowsKits/Include/ucrt",
        "%workspace%/" + sysroot_path + "/WindowsKits/Include/um",
        "%workspace%/" + sysroot_path + "/WindowsKits/Include/shared",
    ]

    rctx.file(
        "BUILD.bazel",
        """load("@rules_sourcemod//windows:toolchain.bzl", "windows_clang_cl_toolchain")

windows_clang_cl_toolchain(
    name = "cc-toolchain-x86_32-windows",
    sysroot_label = {sysroot_label},
    sysroot_path = {sysroot_path},
    builtin_includes = {builtin_includes},
)
""".format(
            sysroot_label = repr(str(sysroot_label)),
            sysroot_path = repr(sysroot_path),
            builtin_includes = repr(builtin_includes),
        ),
    )

llvm_windows_toolchain = repository_rule(
    implementation = _llvm_windows_toolchain_impl,
    attrs = {
        "sysroot": attr.label(
            mandatory = True,
            doc = "Normalized xwin sysroot target (e.g. @windows_x86_32_sysroot//sysroot).",
        ),
    },
    doc = "Fetches Linux x86_64 LLVM and configures clang-cl/lld-link for windows_x86_32.",
)
