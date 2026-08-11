"""Source lists for building the SourcePawn compiler from source.

These mirror the module definitions in the SourcePawn tree's AMBuild files:

  compiler/AMBuilder  -> SPCOMP_COMPILER_SRCS (minus driver.cpp, added by the
                         binary target since it holds main())
  libsmx/AMBuilder    -> SPCOMP_LIBSMX_SRCS
  vm/AMBuilder        -> SPCOMP_VM_SRCS

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
    "sourcepawn/compiler/data-queue.cpp",
    "sourcepawn/compiler/errors.cpp",
    "sourcepawn/compiler/expressions.cpp",
    "sourcepawn/compiler/lexer.cpp",
    "sourcepawn/compiler/main.cpp",
    "sourcepawn/compiler/name-resolution.cpp",
    "sourcepawn/compiler/parse-node.cpp",
    "sourcepawn/compiler/parser.cpp",
    "sourcepawn/compiler/pool-objects.cpp",
    "sourcepawn/compiler/rtti-builder.cpp",
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
#
# utils/pool-allocator.cpp is shared by the compiler and the VM -- built once
# into upstream's libsourcepawn_static alongside vm/ and linked into both from
# there (AMBuildScript's BuildStaticCoreLib). Listed here rather than in
# SPCOMP_COMPILER_SRCS since sourcepawn_compiler (sdk.BUILD.bazel) already
# depends on sourcepawn_vm -- compiling it once here satisfies both without a
# new BUILD target to mirror upstream's separate static-lib module.
SPCOMP_VM_SRCS = [
    "sourcepawn/utils/pool-allocator.cpp",
    "sourcepawn/vm/api.cpp",
    "sourcepawn/vm/base-runtime.cpp",
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
    "sourcepawn/vm/plugin-runtime.cpp",
    "sourcepawn/vm/rtti.cpp",
    "sourcepawn/vm/runtime-helpers.cpp",
    "sourcepawn/vm/scripted-invoker.cpp",
    "sourcepawn/vm/smx-image.cpp",
    "sourcepawn/vm/stack-frames.cpp",
    "sourcepawn/vm/watchdog_timer.cpp",
]

# The VM's per-architecture backend. Only one of these is ever compiled.
#
# SourcePawn's own AMBuildScript enables the JIT (has_jit) for both x86 and
# x86_64, so jit.cpp/linking.cpp are common to both lists below rather than
# an x86-only extra. x86's assembler is header-only (assembler-x86.h/
# macro-assembler-x86.h, no .cpp); x86_64's still has one
# (macro-assembler-x64.cpp). See sourcemod/sdk.BUILD.bazel's sourcepawn_vm
# for the corresponding defines (SP_HAS_JIT, unconditional).
SPCOMP_VM_SRCS_X86_64 = [
    "sourcepawn/vm/jit.cpp",
    "sourcepawn/vm/linking.cpp",
    "sourcepawn/vm/x64/assembler-x64.cpp",
    "sourcepawn/vm/x64/code-stubs-x64.cpp",
    "sourcepawn/vm/x64/features-x64.cpp",
    "sourcepawn/vm/x64/jit_x64.cpp",
    "sourcepawn/vm/x64/macro-assembler-x64.cpp",
]

SPCOMP_VM_SRCS_X86 = [
    "sourcepawn/vm/jit.cpp",
    "sourcepawn/vm/linking.cpp",
    "sourcepawn/vm/x86/code-stubs-x86.cpp",
    "sourcepawn/vm/x86/features-x86.cpp",
    "sourcepawn/vm/x86/jit_x86.cpp",
]

# amtl's argument parser is a real translation unit, not header-only, and the
# compiler's driver depends on it for its option handling.
SPCOMP_AMTL_SRCS = [
    "public/amtl/amtl/experimental/am-argparser.cpp",
]
