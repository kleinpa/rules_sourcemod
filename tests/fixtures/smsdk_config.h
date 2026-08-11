// Minimal extension configuration used by the analysis-test fixtures.
#ifndef _RULES_SOURCEMOD_TESTS_SMSDK_CONFIG_
#define _RULES_SOURCEMOD_TESTS_SMSDK_CONFIG_

#define SMEXT_CONF_NAME "Test Extension"
#define SMEXT_CONF_DESCRIPTION "Fixture for rules_sourcemod analysis tests"
#define SMEXT_CONF_VERSION "0.0.0"
#define SMEXT_CONF_AUTHOR "rules_sourcemod"
#define SMEXT_CONF_URL ""
#define SMEXT_CONF_LOGTAG "TEST"
#define SMEXT_CONF_LICENSE "GPL"
#define SMEXT_CONF_DATESTRING __DATE__

#define SMEXT_LINK(name) SDKExtension *g_pExtensionIface = name;

#endif  // _RULES_SOURCEMOD_TESTS_SMSDK_CONFIG_
