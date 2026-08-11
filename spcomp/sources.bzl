"""Source lists for building the SourcePawn compiler from source.

These mirror the module definitions in the SourcePawn tree's AMBuild files:

  compiler/AMBuilder  -> SPCOMP_COMPILER_SRCS (minus driver.cpp, added by the
                         binary target since it holds main())
  libsmx/AMBuilder    -> SPCOMP_LIBSMX_SRCS
  vm/AMBuilder        -> SPCOMP_VM_SRCS

The lists are explicit rather than globbed, because the upstream trees contain
sources that are deliberately *not* part of a normal build: `exp/` holds an
experimental second compiler, `vm/dll_exports.cpp` belongs to the shared library
rather than the executable, and the VM has mutually exclusive backends per
architecture. A glob would silently pick up the wrong ones.

Keeping them here (rather than inline in the BUILD overlay) means the overlay
stays readable and these can be diffed against upstream's AMBuilder files when
bumping the pinned SourcePawn version.
"""

# compiler/AMBuilder. `driver.cpp` holds main() and is added by the cc_binary.
SPCOMP_COMPILER_SRCS = [
    "sourcepawn/compiler/array-helpers.cpp",
    "sourcepawn/compiler/assembler.cpp",
    "sourcepawn/compiler/builtin-generator.cpp",
    "sourcepawn/compiler/code-generator.cpp",
    "sourcepawn/compiler/compile-context.cpp",
    "sourcepawn/compiler/data-queue.cpp",
    "sourcepawn/compiler/errors.cpp",
    "sourcepawn/compiler/expressions.cpp",
    "sourcepawn/compiler/lexer.cpp",
    "sourcepawn/compiler/main.cpp",
    "sourcepawn/compiler/name-resolution.cpp",
    "sourcepawn/compiler/parse-node.cpp",
    "sourcepawn/compiler/parser.cpp",
    "sourcepawn/compiler/pool-allocator.cpp",
    "sourcepawn/compiler/pool-objects.cpp",
    "sourcepawn/compiler/sci18n.cpp",
    "sourcepawn/compiler/scopes.cpp",
    "sourcepawn/compiler/sctracker.cpp",
    "sourcepawn/compiler/semantics.cpp",
    "sourcepawn/compiler/source-file.cpp",
    "sourcepawn/compiler/source-manager.cpp",
    "sourcepawn/compiler/symbols.cpp",
    "sourcepawn/compiler/type-checker.cpp",
    "sourcepawn/compiler/types.cpp",
]

# libsmx/AMBuilder — .smx container writer.
SPCOMP_LIBSMX_SRCS = [
    "sourcepawn/libsmx/data-pool.cpp",
    "sourcepawn/libsmx/smx-builder.cpp",
]

# vm/AMBuilder, architecture-independent portion.
#
# The compiler links the VM because `assembler.cpp` runs the freshly assembled
# binary through `ISourcePawnEnvironment` to verify it before writing the .smx.
# `dll_exports.cpp` is excluded: it belongs to the libsourcepawn shared library.
SPCOMP_VM_SRCS = [
    "sourcepawn/vm/api.cpp",
    "sourcepawn/vm/base-context.cpp",
    "sourcepawn/vm/builtins.cpp",
    "sourcepawn/vm/code-allocator.cpp",
    "sourcepawn/vm/code-stubs.cpp",
    "sourcepawn/vm/compiled-function.cpp",
    "sourcepawn/vm/control-flow.cpp",
    "sourcepawn/vm/debug-metadata.cpp",
    "sourcepawn/vm/debugging.cpp",
    "sourcepawn/vm/environment.cpp",
    "sourcepawn/vm/file-utils.cpp",
    "sourcepawn/vm/graph-builder.cpp",
    "sourcepawn/vm/interpreter.cpp",
    "sourcepawn/vm/md5/md5.cpp",
    "sourcepawn/vm/method-info.cpp",
    "sourcepawn/vm/method-verifier.cpp",
    "sourcepawn/vm/opcodes.cpp",
    "sourcepawn/vm/plugin-context.cpp",
    "sourcepawn/vm/plugin-runtime.cpp",
    "sourcepawn/vm/pool-allocator.cpp",
    "sourcepawn/vm/rtti.cpp",
    "sourcepawn/vm/runtime-helpers.cpp",
    "sourcepawn/vm/scripted-invoker.cpp",
    "sourcepawn/vm/smx-v1-image.cpp",
    "sourcepawn/vm/stack-frames.cpp",
    "sourcepawn/vm/watchdog_timer.cpp",
]

# The VM's per-architecture backend. Only one of these is ever compiled.
#
# spcomp is a build tool, so it is built for the *execution* platform, which is
# effectively always 64-bit. That matters beyond source selection: the x86 build
# additionally enables the JIT (`SP_HAS_JIT`, jit.cpp + linking.cpp), which the
# x86_64 backend does not use. Building 64-bit keeps the JIT out of the tool
# entirely.
SPCOMP_VM_SRCS_X86_64 = [
    "sourcepawn/vm/x64/assembler-x64.cpp",
    "sourcepawn/vm/x64/code-stubs-x64.cpp",
    "sourcepawn/vm/x64/macro-assembler-x64.cpp",
]

SPCOMP_VM_SRCS_X86 = [
    "sourcepawn/vm/jit.cpp",
    "sourcepawn/vm/linking.cpp",
    "sourcepawn/vm/x86/assembler-x86.cpp",
    "sourcepawn/vm/x86/code-stubs-x86.cpp",
    "sourcepawn/vm/x86/jit_x86.cpp",
]

# amtl's argument parser is a real translation unit, not header-only, and the
# compiler's driver depends on it for its option handling.
SPCOMP_AMTL_SRCS = [
    "public/amtl/amtl/experimental/am-argparser.cpp",
]
