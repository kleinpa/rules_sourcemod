"""Source lists for building the SourcePawn compilers from source.

These mirror the module definitions in the SourcePawn tree's AMBuild files:

  compiler/AMBuilder        -> SPCOMP_COMPILER_SRCS (minus driver.cpp, added by
                               the binary target since it holds main())
  legacy-compiler/AMBuilder -> SPCOMP_LEGACY_COMPILER_SRCS (likewise)
  libsmx/AMBuilder          -> SPCOMP_LIBSMX_SRCS
  utils/AMBuilder           -> SPCOMP_UTILS_SRCS
  vm/AMBuilder              -> SPCOMP_VM_SRCS and the per-arch lists
  third_party/AMBuild.mimalloc -> SPCOMP_MIMALLOC_SRCS

SourcePawn 2 ships two compilers from one tree. `compiler/` is spcomp proper,
the SourcePawn 2 compiler; it still accepts the classic language (it is what
SourceMod's own bundled plugins are built with), but with 2.0's semantics --
heap arrays, no VFormat(), and so on -- and it defines `__sourcepawn2` so
scripts can tell. `legacy-compiler/` is the pre-2.0 compiler, frozen, and
built as `oldspcomp`; SourceMod packages both in its scripting/ directory.
The two directories carry files of the same names, so each is its own list
rather than one list with a directory prefix.

The lists are explicit rather than globbed, because the upstream trees contain
sources that are deliberately *not* part of a normal build -- the VM has
mutually exclusive backends per architecture, for one. A glob would silently
pick up the wrong ones.

Keeping them here (rather than inline in the BUILD overlay) means the overlay
stays readable and these can be diffed against upstream's AMBuilder files when
bumping the pinned SourcePawn version.
"""

# compiler/AMBuilder. `driver.cpp` holds main() and is added by the cc_binary.
SPCOMP_COMPILER_SRCS = [
    "sourcepawn/compiler/array-helpers.cpp",
    "sourcepawn/compiler/assembler.cpp",
    "sourcepawn/compiler/ast-printer.cpp",
    "sourcepawn/compiler/builtin-generator.cpp",
    "sourcepawn/compiler/code-generator.cpp",
    "sourcepawn/compiler/coercion-rules.cpp",
    "sourcepawn/compiler/compile-context.cpp",
    "sourcepawn/compiler/constant-fold.cpp",
    "sourcepawn/compiler/data-queue.cpp",
    "sourcepawn/compiler/errors.cpp",
    "sourcepawn/compiler/ir-node.cpp",
    "sourcepawn/compiler/lexer.cpp",
    "sourcepawn/compiler/main.cpp",
    "sourcepawn/compiler/name-resolution.cpp",
    "sourcepawn/compiler/parse-node.cpp",
    "sourcepawn/compiler/parser.cpp",
    "sourcepawn/compiler/pool-objects.cpp",
    "sourcepawn/compiler/rtti-builder.cpp",
    "sourcepawn/compiler/sci18n.cpp",
    "sourcepawn/compiler/scopes.cpp",
    "sourcepawn/compiler/semantics.cpp",
    "sourcepawn/compiler/semantics-types.cpp",
    "sourcepawn/compiler/source-file.cpp",
    "sourcepawn/compiler/source-manager.cpp",
    "sourcepawn/compiler/symbols.cpp",
    "sourcepawn/compiler/types.cpp",
]

# legacy-compiler/AMBuilder. Same convention: `driver.cpp` is the binary's.
SPCOMP_LEGACY_COMPILER_SRCS = [
    "sourcepawn/legacy-compiler/array-helpers.cpp",
    "sourcepawn/legacy-compiler/assembler.cpp",
    "sourcepawn/legacy-compiler/ast-printer.cpp",
    "sourcepawn/legacy-compiler/builtin-generator.cpp",
    "sourcepawn/legacy-compiler/code-generator.cpp",
    "sourcepawn/legacy-compiler/coercion-rules.cpp",
    "sourcepawn/legacy-compiler/compile-context.cpp",
    "sourcepawn/legacy-compiler/data-queue.cpp",
    "sourcepawn/legacy-compiler/errors.cpp",
    "sourcepawn/legacy-compiler/expressions.cpp",
    "sourcepawn/legacy-compiler/lexer.cpp",
    "sourcepawn/legacy-compiler/main.cpp",
    "sourcepawn/legacy-compiler/name-resolution.cpp",
    "sourcepawn/legacy-compiler/parse-node.cpp",
    "sourcepawn/legacy-compiler/parser.cpp",
    "sourcepawn/legacy-compiler/pool-objects.cpp",
    "sourcepawn/legacy-compiler/rtti-builder.cpp",
    "sourcepawn/legacy-compiler/sci18n.cpp",
    "sourcepawn/legacy-compiler/scopes.cpp",
    "sourcepawn/legacy-compiler/sctracker.cpp",
    "sourcepawn/legacy-compiler/semantics.cpp",
    "sourcepawn/legacy-compiler/source-file.cpp",
    "sourcepawn/legacy-compiler/source-manager.cpp",
    "sourcepawn/legacy-compiler/symbols.cpp",
    "sourcepawn/legacy-compiler/type-checker.cpp",
    "sourcepawn/legacy-compiler/types.cpp",
]

# libsmx/AMBuilder — .smx container writer.
SPCOMP_LIBSMX_SRCS = [
    "sourcepawn/libsmx/data-pool.cpp",
    "sourcepawn/libsmx/smx-builder.cpp",
]

# utils/AMBuilder. Shared by the compilers and the VM -- built once into
# upstream's libsourcepawn_static alongside vm/ and linked into everything from
# there (AMBuildScript's BuildStaticCoreLib). Compiled into sourcepawn_vm
# (sdk.BUILD.bazel) for the same reason: both compilers already depend on it.
SPCOMP_UTILS_SRCS = [
    "sourcepawn/utils/pool-allocator.cpp",
]

# procmap.cpp parses /proc/self/maps: SourcePawn 2 needs every scripted
# address to fit in a cell_t, and on Linux finding a free chunk below 2GB
# means walking the existing mappings. Linux-only in upstream's AMBuilder.
SPCOMP_UTILS_SRCS_LINUX = [
    "sourcepawn/utils/procmap.cpp",
]

# vm/AMBuilder, the portion built on every platform and architecture.
#
# The compilers link the VM because each `assembler.cpp` runs the freshly
# assembled binary through `ISourcePawnEnvironment` to verify it before writing
# the .smx. `dll_exports.cpp` is excluded: it belongs to the libsourcepawn
# shared library.
#
# Both bytecode generations are always present: `legacy/` runs .smx files the
# old compiler produced (the V1 VM), `v2/` the SourcePawn 2 ones. Which one a
# plugin gets is decided per file at load time from its header, so a server
# needs both, and there is no configuration that builds only one.
SPCOMP_VM_SRCS = [
    "sourcepawn/vm/api.cpp",
    "sourcepawn/vm/base-runtime.cpp",
    "sourcepawn/vm/code-allocator.cpp",
    "sourcepawn/vm/code-stubs.cpp",
    "sourcepawn/vm/compiled-function.cpp",
    "sourcepawn/vm/debug-metadata.cpp",
    "sourcepawn/vm/debugging.cpp",
    "sourcepawn/vm/environment.cpp",
    "sourcepawn/vm/file-utils.cpp",
    "sourcepawn/vm/heap.cpp",
    "sourcepawn/vm/md5/md5.cpp",
    "sourcepawn/vm/objects.cpp",
    "sourcepawn/vm/rtti.cpp",
    "sourcepawn/vm/smx-image.cpp",
    "sourcepawn/vm/stack-frames.cpp",
    "sourcepawn/vm/type-cache.cpp",
    "sourcepawn/vm/watchdog_timer.cpp",
    # V1 implementation.
    "sourcepawn/vm/legacy/builtins.cpp",
    "sourcepawn/vm/legacy/control-flow.cpp",
    "sourcepawn/vm/legacy/graph-builder.cpp",
    "sourcepawn/vm/legacy/interpreter.cpp",
    "sourcepawn/vm/legacy/method-info.cpp",
    "sourcepawn/vm/legacy/method-verifier.cpp",
    "sourcepawn/vm/legacy/opcodes.cpp",
    "sourcepawn/vm/legacy/plugin-runtime.cpp",
    "sourcepawn/vm/legacy/runtime-helpers.cpp",
    "sourcepawn/vm/legacy/scripted-invoker.cpp",
    # V2 implementation.
    "sourcepawn/vm/v2/control-flow.cpp",
    "sourcepawn/vm/v2/graph-builder.cpp",
    "sourcepawn/vm/v2/interpreter.cpp",
    "sourcepawn/vm/v2/lowering/lowering.cpp",
    "sourcepawn/vm/v2/lowering/ll-op.cpp",
    "sourcepawn/vm/v2/method-info.cpp",
    "sourcepawn/vm/v2/method-verifier.cpp",
    "sourcepawn/vm/v2/opcodes.cpp",
    "sourcepawn/vm/v2/runtime.cpp",
    "sourcepawn/vm/v2/runtime-helpers.cpp",
    "sourcepawn/vm/v2/scripted-invoker.cpp",
]

# The VM's per-OS portion. platform-posix.cpp is everything but Windows; macOS
# adds its own file on top of it.
SPCOMP_VM_SRCS_POSIX = ["sourcepawn/vm/platform-posix.cpp"]

SPCOMP_VM_SRCS_MACOS = ["sourcepawn/vm/platform-macos.cpp"]

SPCOMP_VM_SRCS_WINDOWS = ["sourcepawn/vm/platform-windows.cpp"]

# The VM's per-architecture backend. Only one of these is ever compiled.
#
# Each has two parts. virtmem-*.cpp is the address-space reservation that
# keeps scripted addresses under 2GB (a whole 2GB range reserved up front on
# 64-bit; an mmap loop over the low addresses on 32-bit), and is needed
# regardless of the JIT. The rest is the JITs: SourcePawn's own AMBuildScript
# enables both the V1 and the V2 one (SP_JIT_V1/SP_JIT_V2) for x86 and x86_64
# alike, so both are in each list rather than an x86-only extra. The x64
# assembler is shared between the two generations and lives at vm/x64/; x86's
# assembler is header-only (assembler-x86.h/macro-assembler-x86.h, no .cpp).
# See sourcemod/sdk.BUILD.bazel's sourcepawn_vm for the corresponding
# defines (unconditional).
SPCOMP_VM_SRCS_X86_64 = [
    "sourcepawn/vm/virtmem-64bit.cpp",
    "sourcepawn/vm/linking.cpp",
    "sourcepawn/vm/x64/assembler-x64.cpp",
    "sourcepawn/vm/x64/features-x64.cpp",
    "sourcepawn/vm/x64/macro-assembler-x64.cpp",
    "sourcepawn/vm/legacy/jit.cpp",
    "sourcepawn/vm/legacy/x64/code-stubs-x64.cpp",
    "sourcepawn/vm/legacy/x64/jit_x64.cpp",
    "sourcepawn/vm/v2/jit.cpp",
    "sourcepawn/vm/v2/x64/code-stubs-x64.cpp",
    "sourcepawn/vm/v2/x64/jit_x64.cpp",
]

SPCOMP_VM_SRCS_X86 = [
    "sourcepawn/vm/virtmem-32bit.cpp",
    "sourcepawn/vm/linking.cpp",
    "sourcepawn/vm/x86/features-x86.cpp",
    "sourcepawn/vm/legacy/jit.cpp",
    "sourcepawn/vm/legacy/x86/code-stubs-x86.cpp",
    "sourcepawn/vm/legacy/x86/jit_x86.cpp",
    "sourcepawn/vm/v2/jit.cpp",
    "sourcepawn/vm/v2/x86/code-stubs-x86.cpp",
    "sourcepawn/vm/v2/x86/jit_x86.cpp",
]

# third_party/AMBuild.mimalloc. The list is upstream's, and shorter than the
# directory: mimalloc's own build splits some translation units into files
# that are `#include`d by a sibling rather than compiled on their own
# (alloc.c pulls in free.c, page.c pulls in page-queue.c, prim/prim.c selects
# the per-OS prim/<os>/prim.c), so those reach the compiler through the
# textual headers in sdk.BUILD.bazel's mimalloc target, not through this
# list.
SPCOMP_MIMALLOC_SRCS = [
    "sourcepawn/third_party/mimalloc/src/alloc.c",
    "sourcepawn/third_party/mimalloc/src/alloc-aligned.c",
    "sourcepawn/third_party/mimalloc/src/alloc-posix.c",
    "sourcepawn/third_party/mimalloc/src/arena.c",
    "sourcepawn/third_party/mimalloc/src/arena-meta.c",
    "sourcepawn/third_party/mimalloc/src/bitmap.c",
    "sourcepawn/third_party/mimalloc/src/heap.c",
    "sourcepawn/third_party/mimalloc/src/init.c",
    "sourcepawn/third_party/mimalloc/src/libc.c",
    "sourcepawn/third_party/mimalloc/src/options.c",
    "sourcepawn/third_party/mimalloc/src/os.c",
    "sourcepawn/third_party/mimalloc/src/page.c",
    "sourcepawn/third_party/mimalloc/src/page-map.c",
    "sourcepawn/third_party/mimalloc/src/random.c",
    "sourcepawn/third_party/mimalloc/src/stats.c",
    "sourcepawn/third_party/mimalloc/src/theap.c",
    "sourcepawn/third_party/mimalloc/src/threadlocal.c",
    "sourcepawn/third_party/mimalloc/src/prim/prim.c",
]

# amtl's argument parser is a real translation unit, not header-only, and both
# compilers' drivers depend on it for their option handling.
SPCOMP_AMTL_SRCS = [
    "public/amtl/amtl/experimental/am-argparser.cpp",
]
