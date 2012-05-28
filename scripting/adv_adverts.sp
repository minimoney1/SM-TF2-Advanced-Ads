#pragma semicolon 1
//Comment out this line if you want to use this on something other than tf2
//#define TF2COLORS

#include <sourcemod>
#undef REQUIRE_EXTENSIONS
#include <steamtools>
#define REQUIRE_EXTENSIONS
#include <updater>
#if defined TF2COLORS
#include <morecolors>
#else
#include <colors>
#endif

#include <smlib>
#include <regex>


#define PLUGIN_VERSION "1.0"

#define UPDATE_URL "https://raw.github.com/minimoney1/SM-TF2-Advanced-Ads/master/update.txt"

public Plugin:myinfo = 
{
	name        = "Extended Advertisements",
	author      = "Mini",
	description = "Extended advertisement system for TF2's new color abilities for developers",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/"
};

new Handle:g_hPluginEnabled = INVALID_HANDLE;
new Handle:g_hAdvertDelay = INVALID_HANDLE;
new Handle:g_hAdvertFile = INVALID_HANDLE;
new Handle:g_hAdvertisements = INVALID_HANDLE;
new Handle:g_hAdvertTimer = INVALID_HANDLE;
new Handle:g_hDynamicTagRegex = INVALID_HANDLE;

new Handle:g_hCenterAd[MAXPLAYERS + 1];

new bool:g_bPluginEnabled;
new Float:g_fAdvertDelay;
new bool:g_bUseSteamTools;


new bool:g_bTickrate = true;
new g_iTickrate;
new g_iFrames = 0;
new Float:g_fTime;
new String:g_strConfigPath[PLATFORM_MAX_PATH];

static String:g_tagRawText[14][128] = 
{
	"",
	"{IP}",
	"{FULL_IP}",
	"{PORT}",
	"{CURRENTMAP}",
	"{NEXTMAP}",
	"{TICKRATE}",
	"{SERVER_TIME}",
	"{SERVER_TIME24}",
	"{SERVER_DATE}",
	"{TIMELEFT}",
	"{CLIENT_NAME}",
	"{CLIENT_STEAMID}",
	"{CLIENT_IP}"
};

static String:g_strConVarBoolText[_:2][5] =
{
	"OFF",
	"ON"
};

static g_iTColors[13][3]         = 
{
	{255, 255, 255}, 
	{255, 0, 0},    
	{0, 255, 0}, 
	{0, 0, 255}, 
	{255, 255, 0}, 
	{255, 0, 255}, 
	{0, 255, 255}, 
	{255, 128, 0}, 
	{255, 0, 128}, 
	{128, 255, 0}, 
	{0, 255, 128}, 
	{128, 0, 255}, 
	{0, 128, 255}
};
static String:g_sTColors[13][12] = 
{
	"{WHITE}",       
	"{RED}",        
	"{GREEN}",   
	"{BLUE}",    
	"{YELLOW}",    
	"{PURPLE}",    
	"{CYAN}",      
	"{ORANGE}",    
	"{PINK}",      
	"{OLIVE}",     
	"{LIME}",      
	"{VIOLET}",    
	"{LIGHTBLUE}"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	switch (GetExtensionFileStatus("steamtools.ext"))
	{
		case 1:
		{
			g_bUseSteamTools = true;
		}
		default:
		{
			g_bUseSteamTools = false;
		}
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	CreateConVar("sm_extended_advertisements_version", PLUGIN_VERSION, "Display advertisements", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hPluginEnabled = CreateConVar("sm_extended_advertisements_enabled", "1", "Is plugin enabled?", 0, true, 0.0, true, 1.0);
	g_hAdvertDelay = CreateConVar("sm_extended_advertisements_delay", "30.0", "The delay time between each advertisement");
	g_hAdvertFile = CreateConVar("sm_extended_advertisements_file", "configs/extended_advertisements.txt", "What is the file directory of the advertisements file");
	
	
	HookConVarChange(g_hPluginEnabled, OnEnableChange);
	HookConVarChange(g_hAdvertDelay, OnAdvertDelayChange);
	HookConVarChange(g_hAdvertFile, OnAdvertFileChange);
	
	GetConVarValues();
	
	LoadTranslations("extended_advertisements.phrases");
	
	
	RegAdminCmd("sm_reloadads", Command_ReloadAds, ADMFLAG_GENERIC);
	
	
	AutoExecConfig();
	
	g_hDynamicTagRegex = CompileRegex("\\{((CONVAR)|(CONVAR_BOOL)):[0-9a-zA-z]{1,}\\}");
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnGameFrame() 
{
	if (g_bTickrate) 
	{
		g_iFrames++;
		
		new Float:fTime = GetEngineTime();
		if (fTime >= g_fTime) 
		{
			if (g_iFrames == g_iTickrate) 
			{
				g_bTickrate = false;
			} 
			else 
			{
				g_iTickrate = g_iFrames;
				g_iFrames   = 0;    
				g_fTime     = fTime + 1.0;
			}
		}
	}
}

public OnConfigsExecuted()
{
	GetConVarValues();
	if (g_bPluginEnabled)
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer);
		}
		else
			g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer);
	}
}


stock GetConVarValues()
{
	g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
	g_fAdvertDelay = GetConVarFloat(g_hAdvertDelay);
	decl String:advertPath[PLATFORM_MAX_PATH];
	GetConVarString(g_hAdvertFile, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strConfigPath, sizeof(g_strConfigPath), advertPath);
}

public OnEnableChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
}

public OnAdvertDelayChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	if (g_bPluginEnabled)
	{
		new Float:advertDelay = StringToFloat(newValue);
		CreateTimer(float(StringToInt(oldValue)), TimerDelayChange, advertDelay, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnAdvertFileChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	decl String:advertPath[PLATFORM_MAX_PATH];
	strcopy(advertPath, sizeof(advertPath), newValue);
	BuildPath(Path_SM, g_strConfigPath, sizeof(g_strConfigPath), advertPath);
}

public Action:TimerDelayChange(Handle:delayTimer, any:advertDelay)
{
	if (g_bPluginEnabled)
	{
		KillTimer(g_hAdvertTimer);
		g_hAdvertTimer = CreateTimer(advertDelay, AdvertisementTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
}

public Action:AdvertisementTimer(Handle:advertTimer)
{
	if (g_bPluginEnabled)
	{
		decl String:sFlags[16], String:sText[256], String:sType[6], String:sBuffer[256];
		new flagBits = -1;
		
		KvGetString(g_hAdvertisements, "type",  sType,  sizeof(sType));
		KvGetString(g_hAdvertisements, "text",  sText,  sizeof(sText));
		KvGetString(g_hAdvertisements, "flags", sFlags, sizeof(sFlags), "none");
		
		
		ReplaceAdText(sText, sText, sizeof(sText));
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		if (!StrEqual(sFlags, "none"))
		{
			flagBits = ReadFlagString(sFlags);
		}
		else
			flagBits = -1;
		if (StrContains(sType, "C") != -1) 
		{
			CRemoveTags(sBuffer, sizeof(sBuffer));
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				if (Client_CanViewAds(client, flagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					PrintCenterText(client, sBuffer);	
					new Handle:hCenterAd;
					g_hCenterAd[client] = CreateDataTimer(1.0, Timer_CenterAd, hCenterAd, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
					WritePackCell(hCenterAd,   client);
					WritePackString(hCenterAd, sBuffer);
					
				}
			}
			strcopy(sBuffer, sizeof(sBuffer), sText);
		}
		if (StrContains(sType, "H") != -1) 
		{
			CRemoveTags(sBuffer, sizeof(sBuffer));
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				if (Client_CanViewAds(client, flagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					PrintHintText(client, sBuffer);
				}
			}
			strcopy(sBuffer, sizeof(sBuffer), sText);
		}
		if (StrContains(sType, "M") != -1) 
		{
			new Handle:hPl = CreatePanel();
			DrawPanelText(hPl, sBuffer);
			SetPanelCurrentKey(hPl, 10);
			
			CRemoveTags(sBuffer, sizeof(sBuffer));
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{	
				if (Client_CanViewAds(client, flagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					SendPanelToClient(hPl, client, Handler_DoNothing, 10);
				}
			}
			strcopy(sBuffer, sizeof(sBuffer), sText);
			
			CloseHandle(hPl);
		}
		if (StrContains(sType, "S") != -1) 
		{
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				if (Client_CanViewAds(client, flagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					CPrintToChat(client, sBuffer);
				}
			}
		}
		if (StrContains(sType, "T") != -1) 
		{
			decl String:sColor[16];
			new iColor = -1, iPos = BreakString(sText, sColor, sizeof(sColor));
			
			for (new i = 0; i < sizeof(g_sTColors); i++) 
			{
				if (StrEqual(sColor, g_sTColors[i])) 
				{
					iColor = i;
				}
			}
			
			if (iColor == -1) 
			{
				iPos     = 0;
				iColor   = 0;
			}
			
			CRemoveTags(sBuffer, sizeof(sBuffer));
			
			new Handle:hKv = CreateKeyValues("Stuff", "title", sBuffer[iPos]);
			KvSetColor(hKv, "color", g_iTColors[iColor][0], g_iTColors[iColor][1], g_iTColors[iColor][2], 255);
			KvSetNum(hKv,   "level", 1);
			KvSetNum(hKv,   "time",  10);
			
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				if (Client_CanViewAds(client, flagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					CreateDialog(client, hKv, DialogType_Msg);
				}
			}
			strcopy(sBuffer, sizeof(sBuffer), sText);
			CloseHandle(hKv);
		}
	}
}

public Handler_DoNothing(Handle:menu, MenuAction:action, param1, param2) {}

public Action:Timer_CenterAd(Handle:timer, Handle:pack) 
{
	decl String:sText[256];
	static iCount = 0;
	
	ResetPack(pack);
	new iClient = ReadPackCell(pack);
	ReadPackString(pack, sText, sizeof(sText));
	
	if (IsClientInGame(iClient) && ++iCount < 5) 
	{
		PrintCenterText(iClient, sText);
		
		return Plugin_Continue;
	}
	
	else 
	{
		iCount = 0;
		g_hCenterAd[iClient] = INVALID_HANDLE;
		
		return Plugin_Stop;
	}
}

public Action:Command_ReloadAds(client, args)
{
	if (Client_IsValid(client) && g_bPluginEnabled)
	{
		parseAdvertisements();
		Client_PrintToChat(client, true, "%t %t", "Advert_Tag", "Config_Reloaded");
	}
	return Plugin_Handled;
}

stock parseAdvertisements()
{
	if (g_bPluginEnabled)
	{
		if (g_hAdvertisements != INVALID_HANDLE)
			CloseHandle(g_hAdvertisements);
		g_hAdvertisements = CreateKeyValues("Advertisements");
		
		if (FileExists(g_strConfigPath)) 
		{
			FileToKeyValues(g_hAdvertisements, g_strConfigPath);
			KvGotoFirstSubKey(g_hAdvertisements);
		} 
		else 
		{
			SetFailState("Advertisement file \"%s\" was not found.", g_strConfigPath);
		}
	}
}

stock ReplaceAdText(const String:inputText[], String:outputText[], outputText_maxLength)
{
	if (g_bPluginEnabled)
	{
		strcopy(outputText, outputText_maxLength, inputText);
		new dynamicTagCount = MatchRegex(g_hDynamicTagRegex, inputText);
		decl String:matchedTag[64], String:tempString[64];
		for (new i = 0; i < dynamicTagCount; i++)
		{
			GetRegexSubString(g_hDynamicTagRegex, i, matchedTag, sizeof(matchedTag));
			strcopy(tempString, sizeof(tempString), matchedTag);
			if (StrContains(tempString, "CONVAR_BOOL"))
			{
				ReplaceString(tempString, sizeof(tempString), "{CONVAR_BOOL:", "");
				ReplaceString(tempString, sizeof(tempString), "}", "");
				new Handle:conVarFound = FindConVar(tempString);
				if (conVarFound != INVALID_HANDLE)
					strcopy(tempString, sizeof(tempString), g_strConVarBoolText[GetConVarBool(conVarFound)]);
				else
					tempString = "";
				ReplaceString(outputText, outputText_maxLength, matchedTag, tempString);
			}
			else
			{
				ReplaceString(tempString, sizeof(tempString), "{CONVAR:", "");
				ReplaceString(tempString, sizeof(tempString), "}", "");
				new Handle:conVarFound = FindConVar(tempString);
				if (conVarFound != INVALID_HANDLE)
				{
					decl String:strConVarValue[64];
					GetConVarString(conVarFound, strConVarValue, sizeof(strConVarValue));
					strcopy(tempString, sizeof(tempString), strConVarValue);
				}
				else
					tempString = "";
				ReplaceString(outputText, outputText_maxLength, matchedTag, tempString);
			}
		}
		
		new i = 1;
		decl String:strTemp[256];
		if (StrContains(outputText, g_strConVarBoolText[i]) != -1)
		{
			GetServerIP(strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			GetServerIP(strTemp, sizeof(strTemp), true);
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			Format(strTemp, sizeof(strTemp), "%i", Server_GetPort());
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			GetCurrentMap(strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			GetNextMap(strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			IntToString(g_iTickrate, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			FormatTime(strTemp, sizeof(strTemp), "%I:%M:%S%p");
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			FormatTime(strTemp, sizeof(strTemp), "%H:%M:%S");
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			FormatTime(strTemp, sizeof(strTemp), "%x");
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			new iMins, iSecs, iTimeLeft;
				
			if (GetMapTimeLeft(iTimeLeft) && iTimeLeft > 0) 
			{
				iMins = iTimeLeft / 60;
				iSecs = iTimeLeft % 60;
			}
			
			Format(strTemp, sizeof(strTemp), "%d:%02d", iMins, iSecs);
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		strTemp[0] = '\0';
	}
}

stock ReplaceClientText(client, const String:inputText[], String:outputText[], outputText_maxLength)
{
	if (Client_IsValid(client) && g_bPluginEnabled)
	{
		new i = 11;
		decl String:strTemp[256];
		strcopy(outputText, outputText_maxLength, inputText);
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			GetClientName(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			GetClientAuthString(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		i++;
		if (StrContains(outputText, g_tagRawText[i]) != -1)
		{
			GetClientIP(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp);
		}
		strTemp[0] = '\0';
	}
}

stock GetServerIP(String:ipAddress[], serverIP_maxLength, bool:fullIp = false)
{
	Server_GetIPString(ipAddress, serverIP_maxLength, g_bUseSteamTools);
	if (fullIp)
	{
		new serverPublicPort = Server_GetPort();
		Format(ipAddress, serverIP_maxLength, "%s:%i", ipAddress, serverPublicPort);
	}
}

stock bool:Client_CanViewAds(client, clientFlagBits)
{
	if (clientFlagBits == -1)
		return true;
	if (CheckCommandAccess(client, "extended_advert", clientFlagBits) || CheckCommandAccess(client, "extended_adverts", ADMFLAG_ROOT))
		return true;
	return false;
}