"""Public API for rules_sourcemod.

Load everything from here; the internal package layout is not a stable
interface.

    load("@rules_sourcemod//:defs.bzl",
         "sourcemod_extension", "sourcemod_plugin")
"""

load("//extension:defs.bzl", _sourcemod_extension = "sourcemod_extension")
load("//sourcemod:providers.bzl", _SourceModPackageInfo = "SourceModPackageInfo")
load("//spcomp:plugin.bzl", _sourcemod_plugin = "sourcemod_plugin")

sourcemod_extension = _sourcemod_extension
sourcemod_plugin = _sourcemod_plugin
SourceModPackageInfo = _SourceModPackageInfo
