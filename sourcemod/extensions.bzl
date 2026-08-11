"""Module extension that materializes the SourceMod SDK."""

load("//sourcemod:repositories.bzl", "sourcemod_sdk_repository")

def _sourcemod_impl(_module_ctx):
    sourcemod_sdk_repository(name = "sourcemod_sdk")

sourcemod = module_extension(
    implementation = _sourcemod_impl,
    doc = """Fetches the pinned SourceMod SDK sources and SourcePawn compiler.

Produces one repository:

  @sourcemod_sdk - SDK headers, smsdk_ext.cpp, and the SourcePawn compiler,
                   exposed as targets that build with the consumer's own
                   toolchain. The spcomp toolchain itself is declared in
                   //spcomp, which needs no repository of its own.
""",
)
