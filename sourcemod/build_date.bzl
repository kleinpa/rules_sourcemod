"""Pins the build timestamp, so identical sources produce identical artifacts.

SourceMod, Metamod and SourcePawn each stamp the moment of the build into
their outputs, at three kinds of site, and each needs a different fix:

`__DATE__` in C++ that Bazel compiles. Bazel's own C++ toolchain
configuration (rules_cc's unix toolchain, toolchains_llvm likewise) already
appends `-D__DATE__="redacted"` and the same for `__TIME__`/`__TIMESTAMP__`
to every gcc/clang compile, so nothing built through it carries a real date
-- extension code included, a consumer's `SMEXT_CONF_DATESTRING __DATE__`
too. That is not something a copt here could improve on: the toolchain's
flags come last on the command line, so a `-D__DATE__` of ours is
overridden by them. MSVC has no equivalent (`__DATE__` is reserved there and
a `/D` for it is ignored with C4117), and "redacted" is not a date --
`sm version` and `meta version` print `SM_BUILD_TIMESTAMP` and
`SOURCEMM_DATE` straight through. So the four upstream sites that feed
those (`sourcemod_version.h`, `sourcemm_api.cpp`, `metamod_version.h`,
`metamod.h`) are patched at fetch time (//sourcemod:patches,
//hl2sdk:patches) to a fixed literal that is a real `__DATE__` spelling,
"Mmm dd yyyy" with the day space-padded. That holds on every compiler.

The compilers' clock read. spcomp and oldspcomp read the wall clock when
they compile a *plugin*, not when they are themselves built, and inject the
result as SourcePawn's `__DATE__`/`__TIME__`, which plugins/include/core.inc
copies into every .smx's `__version` struct. No compile flag reaches that,
so two more patches teach both compilers SOURCE_DATE_EPOCH
(reproducible-builds.org/specs/source-date-epoch) and `sourcemod_plugin`
passes this in the action environment. The same instant as the literal
above, in seconds since the Unix epoch, which is what that convention
calls for.
"""

BUILD_DATE_EPOCH = "315532800"
