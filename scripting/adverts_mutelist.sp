#include <sourcemod>
#include <extended_adverts>
#undef REQUIRE_PLUGIN
#include <basecomm>
#include <extendedcomm>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0.0"

new bool:g_bLate;
new g_iType;

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
		AddExtraTag("client_comm", ClientMuteList);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (!strcmp(name, "extendedcomm"))
		g_iType = 1;
	else if (!strcmp(name, "basecomm"))
		g_iType = 2;
}

public OnLibraryRemoved(const String:name[])
{
	OnAllPluginsLoaded();
}

public OnAllPluginsLoaded()
{
	if (LibraryExists("extendedcomm"))
		g_iType = 1;
	else if (LibraryExists("basecomm"))
		g_iType = 2;
	else
		g_iType = 0;
}

public OnAdvertsLoaded()
{
	if (!g_bLate)
		AddExtraTag("client_comm", ClientMuteList);
}

public Action:ClientMuteList(const String:advertText[], String:tag[], const String:tagActual[])
{
	if (!g_iType)
		return Plugin_Handled;
	decl String:playerList[512];
	new iMuteLength = 0;
	playerList[0] = '\0';
	if (g_iType == 1)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (((iMuteLength = _:ExtendedComm_GetMuteLength(i)) > 0) || ((ExtendedComm_GetGagLength(i)) > 0))
			{
				if (playerList[0] == '\0')
				{
					Format(playerList, sizeof(playerList), "Clients' Communcation Status: %N (%s)", i, ((iMuteLength > 0) ? "Muted" : "Gagged"));
				}
				else
				{
					Format(playerList, sizeof(playerList), "%s, %N (%s)", playerList, i, ((iMuteLength > 0) ? "Muted" : "Gagged"));
				}
			}
		}
	}
	else if (g_iType == 2)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (((iMuteLength = _:BaseComm_IsClientMuted(i)) > 0) || BaseComm_IsClientGagged(i))
			{
				if (playerList[0] == '\0')
				{
					Format(playerList, sizeof(playerList), "Clients' Communcation Status: %N (%s)", i, ((iMuteLength > 0) ? "Muted" : "Gagged"));
				}
				else
				{
					Format(playerList, sizeof(playerList), "%s, %N (%s)", playerList, i, ((iMuteLength > 0) ? "Muted" : "Gagged"));
				}
			}
		}
	}
	
	return Plugin_Changed;
}