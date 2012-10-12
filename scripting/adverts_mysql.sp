#include <sourcemod>
#include <extended_adverts>

#define PLUGIN_VERSION "1.0.0"
#define DB_CONFIG "adverts_mysql"
#define QUERY  "SELECT id, type, text, flags, game \
				FROM adsmysql"

new bool:g_bLate,
	Handle:g_hConnectionDB = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name        = "Extended Advertisements MYSQL Support",
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
	EstablishDB();
}

stock EstablishDB()
{
	SQL_TConnect(OnConnectionEstablished, DB_CONFIG);
}

public OnConnectionEstablished(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	g_hConnectionDB = hndl;
	
	if (hndl == INVALID_HANDLE || error[0] != '\0')
	{
		LogError("Database Connection: \"%s\".", error);
	}
}


public OnAdvertsLoaded()
{
	if (!g_bLate && g_hConnectionDB != INVALID_HANDLE)
	{
		CreateTimer(3.0, Timer_EstablishDB);
	}
	else
	{
		decl String:query[256];
		SQL_EscapeString(g_hConnectionDB, QUERY, query, sizeof(query));		
		SQL_TQuery(g_hConnectionDB, OnQueryEstablished, QUERY);
	}
}

public OnQueryEstablished(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Database Connection: \"%s\".", error);
	}
	else
	{
		decl String:gameFolder[32];
		GetGameFolderName(gameFolder, sizeof(gameFolder));
		decl String:advertText[512], String:flags[4], String:type[4], String:id[16], String:game[32];
		while (SQL_FetchRow(hndl))
		{
			game[0] = '\0';
			SQL_FetchString(hndl, 4, game, sizeof(game));
			TrimString(game);

			if (!(!strcmp(game, gameFolder, false)))
				continue;

			id[0] = '\0';
			SQL_FetchString(hndl, 0, id, sizeof(id));
			TrimString(id);

			type[0] = '\0';
			SQL_FetchString(hndl, 1, type, sizeof(type));
			TrimString(type);

			advertText[0] = '\0';
			SQL_FetchString(hndl, 2, advertText, sizeof(advertText));
			TrimString(advertText);

			flags[0] = '\0';
			SQL_FetchString(hndl, 3, flags, sizeof(flags));
			TrimString(flags);
			if (!strcmp(flags, "none"))
			{
				AddAdvert(id, type, advertText, _, _, _, true);
			}
			else if (!strcmp(flags, "a"))
			{
				AddAdvert(id, type, advertText, _, "b", _, true);
			}
			else if (!strcmp(flags, ""))
			{
				AddAdvert(id, type, advertText, "b", _, _, true);
			}
		}
	}
}

public Action:Timer_EstablishDB(Handle:timer)
{
	if (g_hConnectionDB != INVALID_HANDLE)
		SetFailState("Couldn't establish connection in time.");
	else
	{
		decl String:query[256];
		SQL_EscapeString(g_hConnectionDB, QUERY, query, sizeof(query));
		SQL_TQuery(g_hConnectionDB, OnQueryEstablished, QUERY);
	}
}