#include <sourcemod>
#include <extended_adverts>

#define PLUGIN_VERSION "1.0.0"

new String:g_strTag[64];
new bool:g_bLoad;

public Plugin:myinfo = 
{
	name        = "Extended Advertisements Prefix",
	author      = "Mini",
	description = "Just an example...",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/"
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	g_bLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	new Handle:cvar = CreateConVar("adv_prefix", "[Adverts]");
	GetConVarString(cvar, g_strTag, sizeof(g_strTag));
	HookConVarChange(cvar, OnConVarChanged);
	if (g_bLoad)
	{
		PrintToChatAll("%s", (AddExtraChatColor("test", 0xBDB76B) ? "Added Color" : "Color Not Added"));
		AddAdvert("", "S", "HALLO");
	}
}

public OnAdvertsLoaded()
{
	if (!g_bLoad)
		PrintToChatAll("%s", (AddExtraChatColor("test", 0xBDB76B) ? "Added Color" : "Color Not Added"));
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	strcopy(g_strTag, sizeof(g_strTag), newValue);
}

public Action:OnAdvertPreClientReplace(client, const advType:curType, const String:advertId[], const String:advertType[], String:advertText[], &advertFlags, &noFlags)
{
	if (curType == advType_Say)
	{
		
			Format(advertText, 512, "{test}%s %s", g_strTag, advertText);
	}
}