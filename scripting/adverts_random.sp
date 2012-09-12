#include <sourcemod>
#include <extended_adverts>

#define PLUGIN_VERSION "1.0.0"


public Plugin:myinfo = 
{
	name        = "Extended Advertisements random diplay order",
	author      = "Mini",
	description = "Just an example...",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/"
};

public Action:OnAdvertPreLoadPre()
{
	decl String:advertId[64];
	GetRandomAdvert(advertId, sizeof(advertId));
	JumpToAdvert(advertId);
	return Plugin_Continue;
}