#include <sourcemod>
#include <extended_adverts>
#include <regex>

#define PLUGIN_VERSION "1.0.0"

new bool:g_bLate;

public Plugin:myinfo = 
{
	name        = "Extended Advertisements {PLAIN:} tag",
	author      = "Mini",
	description = "Just an example...",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/"
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	if (g_bLate)
	{
		AddExtraDynamicClientTag("/\\{PLAIN:[A-Za-z1-9]\\}/", ClientPlainTag, PCRE_CASELESS);
	}
}

public OnAdvertsLoaded()
{
	if (!g_bLate)
	{
		AddExtraDynamicClientTag("/\\{PLAIN:[A-Za-z1-9]\\}/", ClientPlainTag, PCRE_CASELESS);
	}
}

public Action:ClientPlainTag(client, const String:advertText[], String:tag[], const String:tagActual[])
{
	strcopy(tag, 256, tagActual[7]);
	tag[FindCharInString(tag, '}')] = '\0';
	return Plugin_Changed;
}