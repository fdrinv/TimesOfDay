#if defined _jailcore_included_
  #endinput
#endif
#define _jailcore_included_

#define PLUGIN_INC_INT_VERSION 0x01000000

public SharedPlugin __pl_jailcore = 
{
	name = "jailcore",
	file = "jailcore.smx",

	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};