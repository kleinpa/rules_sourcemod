"""Public API for rules_sourcemod."""

load("//private:extension.bzl", _sourcemod_extension = "sourcemod_extension")
load("//private:transition.bzl", _platform_transition_pkg = "platform_transition_pkg")
load(
    "//spcomp:library.bzl",
    _SourcePawnInfo = "SourcePawnInfo",
    _sourcemod_library = "sourcemod_library",
)
load("//spcomp:plugin.bzl", _sourcemod_plugin = "sourcemod_plugin")
load("//spcomp:test.bzl", _sourcemod_test = "sourcemod_test")

SourcePawnInfo = _SourcePawnInfo
sourcemod_extension = _sourcemod_extension
sourcemod_library = _sourcemod_library
sourcemod_plugin = _sourcemod_plugin
sourcemod_test = _sourcemod_test
platform_transition_pkg = _platform_transition_pkg
