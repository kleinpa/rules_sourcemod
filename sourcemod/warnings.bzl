"""Warning suppressions for the AlliedModders and Valve sources.

Everything compiled from @hl2sdk_*, @metamod_source and @sourcemod_sdk is
third-party code, some of it twenty years old, and none of it is warning-clean
under a current compiler with Bazel's default `-Wall`. The noise is not a
finding: it is the same code upstream ships, and a build that prints two hundred
warnings from other people's sources is one where a warning about *our* code
goes unread.

The list is upstream's own. `configure_gcc()` in SourceMod's AMBuildScript
suppresses most of these, so it is the flag set the code was written against;
building it with anything stricter is inventing a standard its authors never
applied. The version gates upstream carries (`if cxx.version >= 'gcc-4.8'`) are
dropped, since nothing that old can compile the C++17 this tree requires.

These are GCC spellings, and only GCC's. Upstream supports both families and
switches flags between them, but doing that here means maintaining two lists
whose contents cannot be checked against each other by anything but a build on
each compiler. A clang build still works; it lands in the same branch, does not
recognize a handful of the options -- `-Wno-maybe-uninitialized` and
`-Wno-class-memaccess` among them -- and says so whenever it emits any other
diagnostic. That is the cost of the simplification, and it is paid in log lines
rather than in behavior.

Two diagnostics survive and cannot be added here, both reported
unconditionally with no controlling -W flag to name:

  * `smsdk_ext.cpp` replaces `operator delete` without `noexcept`, which GCC
    reports as "declaration of 'void operator delete(void*)' has a different
    exception specifier". Upstream fixed this on its 1.13 branch (#2607) but
    not on the 1.12 branch this module tracks.
  * The HL2SDK's `public/tier0/platform.h` does `#define _stricmp stricmp`
    over a name the host headers already define, which GCC reports as
    "'_stricmp' redefined". This is the bulk of the remaining output, since it
    fires in nearly every translation unit that reaches tier0.

Warnings about code in *this* repository are not covered by any of this: there
is no C++ here, only build definitions.
"""

_GCC = [
    # From upstream's configure_gcc().
    "-Wno-unused",
    "-Wno-switch",
    "-Wno-array-bounds",
    "-Wno-unknown-pragmas",
    "-Wno-dangling-else",
    "-Wno-narrowing",
    "-Wno-non-virtual-dtor",
    "-Wno-overloaded-virtual",
    "-Wno-delete-non-virtual-dtor",
    "-Wno-unused-result",
    "-Wno-invalid-offsetof",
    "-Wno-maybe-uninitialized",
    "-Wno-class-memaccess",
    "-Wno-packed-not-aligned",
    # The sources still use the `register` keyword that C++17 removed.
    "-Wno-register",
    # Upstream passes -Wno-deprecated for the same reason: this is C++17-era
    # code using what C++17 deprecated, e.g. wstring_convert in the SourcePawn
    # compiler's codepage handling.
    "-Wno-deprecated-declarations",
    #
    # Not in upstream's list, which predates the compilers that emit these.
    #
    # SourceHook spells CVector's constructors and destructor `CVector<T>()`,
    # which C++20 removed (CWG 2237) and which -Wall warns about ahead of time
    # from GCC 14 on. SourceMod's TopMenu.h and SourceHook's own
    # sourcehook_pibuilder.h both include it, so it lands in several hundred
    # translation units. Suppressible because this tree builds as C++17, where
    # the construct is still legal; under C++20 it is a parse error that no
    # -Wno- can reach.
    "-Wno-template-id-cdtor",
    # Upstream's own flag, spelled -Wno-reorder-ctor for clang (see the css
    # entry in alliedmodders/hl2sdk-manifests): member initializers that do not
    # match declaration order, throughout the HL2SDK's game classes.
    "-Wno-reorder",
    # The HL2SDK's container and string code.
    "-Wno-sign-compare",
    "-Wno-nonnull-compare",
    "-Wno-ignored-attributes",
    # snprintf into a fixed buffer whose size GCC cannot prove is enough.
    "-Wno-format-truncation",
]

# Upstream's MSVC configuration suppresses nothing comparable, so neither does
# this: /W3 there is already quiet about the constructs GCC flags.
UPSTREAM_WARNING_COPTS = select({
    "@rules_cc//cc/compiler:msvc-cl": [],
    "//conditions:default": _GCC,
})
