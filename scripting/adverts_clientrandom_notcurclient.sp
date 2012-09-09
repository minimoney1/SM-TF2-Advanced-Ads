#include <sourcemod>
#include <extended_adverts>

#define PLUGIN_VERSION "1.0.0"

new bool:g_bLate;
new g_iLastClient;

public Plugin:myinfo = 
{
	name        = "Extended Advertisements CLIENT_RANDOM_NOTCURCLIENT tag",
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
		AddExtraTag("client_random_notcurclient", AddExtraClientTag);
	}
}

public OnAdvertsLoaded()
{
	if (!g_bLate)
		AddExtraTag("client_random_notcurclient", AddExtraClientTag);
}

public Action:ClientRandomFunc(cur_client, const String:advertText[], String:tag[], const String:tagActual[])
{
	new client = GetRandomInt(1, MaxClients);
	while ((!IsClientInGame(client)) || (client == g_iLastClient) || (client == cur_client))
	{
		GetRandomInt(1, MaxClients);
	}
	g_iLastClient = client;
	GetClientName(client, tag, MAX_NAME_LENGTH);
	return Plugin_Changed;
}