#pragma semicolon 1
//Comment out this line if you want to use this on something other than tf2
#define ADVERT_TF2COLORS

#include <sourcemod>
#undef REQUIRE_EXTENSIONS
#include <steamtools>
#define REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN
#if defined ADVERT_TF2COLORS
#include <morecolors>
#else
#include <colors>
#endif
#include <regex>
#include <smlib>
#include <extended_adverts>

#define PLUGIN_VERSION "1.1.0"

#if defined ADVERT_TF2COLORS
#define UPDATE_URL "https://raw.github.com/minimoney1/SM-TF2-Advanced-Ads/master/update-tf2.txt"
#else
#define UPDATE_URL "https://raw.github.com/minimoney1/SM-TF2-Advanced-Ads/master/update-nontf2.txt"
#endif

new Handle:g_hPluginEnabled = INVALID_HANDLE;
new Handle:g_hAdvertDelay = INVALID_HANDLE;
new Handle:g_hAdvertFile = INVALID_HANDLE;
new Handle:g_hAdvertisements = INVALID_HANDLE;
new Handle:g_hAdvertTimer = INVALID_HANDLE;
//new Handle:g_hDynamicTagRegex = INVALID_HANDLE;
new Handle:g_hExitPanel = INVALID_HANDLE;
new Handle:g_hExtraTopColorsPath = INVALID_HANDLE;
#if defined ADVERT_TF2COLORS
new Handle:g_hExtraChatColorsPath = INVALID_HANDLE;
new String:g_strExtraChatColorsPath[PLATFORM_MAX_PATH];
#endif

new Handle:g_hCenterAd[MAXPLAYERS + 1];

new Handle:g_hTopColorTrie = INVALID_HANDLE;

new Handle:g_hForwardPreReplace,
	Handle:g_hForwardPreClientReplace,
	Handle:g_hForwardPostAdvert;

new bool:g_bPluginEnabled,
	bool:g_bExitPanel,
	bool:g_bUseSteamTools;

new Float:g_fAdvertDelay;


new bool:g_bTickrate = true;
new g_iTickrate;
new g_iFrames = 0;
new Float:g_fTime;
new String:g_strConfigPath[PLATFORM_MAX_PATH];
new String:g_strExtraTopColorsPath[PLATFORM_MAX_PATH];

static String:g_tagRawText[11][24] = 
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
	"{TIMELEFT}"
};

static String:g_clientRawText[7][32] =
{
	"",
	"{CLIENT_NAME}",
	"{CLIENT_STEAMID}",
	"{CLIENT_IP}",
	"{CLIENT_FULLIP}",
	"{CLIENT_CONNECTION_SECONDS}",
	"{CLIENT_MAPTIME}"
};

static String:g_strConVarBoolText[2][5] =
{
	"OFF",
	"ON"
};

public Plugin:myinfo = 
{
	name        = "Extended Advertisements",
	author      = "Mini",
	description = "Extended advertisement system for TF2's new color abilities for developers",
	version     = EXT_ADVERT_VERSION,
	url         = "http://forums.alliedmods.net/"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("adv_adverts");
	MarkNativeAsOptional("Steam_GetPublicIP");
	MarkNativeAsOptional("Updater_AddPlugin");
	MarkNativeAsOptional("Updater_RemovePlugin");
	CreateNative("AddExtraTopColor", AddTopColorToTrie);
	CreateNative("Client_CanViewAds", CanViewAdvert);
	#if defined ADVERT_TF2COLORS
	CreateNative("AddExtraChatColor", AddChatColorToTrie);
	#endif
	return APLRes_Success;
}

public AddTopColorToTrie(Handle:plugin, numParams)
{
	decl String:colorName[128], colorName_maxLength;
	GetNativeStringLength(1, colorName_maxLength);
	GetNativeString(1, colorName, colorName_maxLength);
	new red = GetNativeCell(2),
		blue = GetNativeCell(3),
		green = GetNativeCell(4),
		alpha = GetNativeCell(5);
	new bool:replace = GetNativeCell(6) ? true : false;
	new color[4];
	color[0] = red;
	color[1] = blue;
	color[2] = green;
	color[3] = alpha;
	return SetTrieArray(g_hTopColorTrie, colorName, color, 4, replace);
}

#if defined ADVERT_TF2COLORS
public AddChatColorToTrie(Handle:plugin, numParams)
{
	decl String:colorName[128], colorName_maxLength;
	GetNativeStringLength(1, colorName_maxLength);
	GetNativeString(1, colorName, colorName_maxLength);
	new hex = GetNativeCell(2);
	
	return CAddColor(colorName, hex);
}
#endif

public OnPluginStart()
{
	CreateConVar("extended_advertisements_version", EXT_ADVERT_VERSION, "Display advertisements", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	#if defined ADVERT_TF2COLORS
	decl String:gameFolderName[12];
	GetGameFolderName(gameFolderName, sizeof(gameFolderName));
	if ((!StrEqual(gameFolderName, "tf", false)) && (!StrEqual(gameFolderName, "tf_beta", false)))
		SetFailState("[Extended Advertisements] You are running a version of this plugin that is incompatible with your game.");
	#endif
	g_hPluginEnabled = CreateConVar("sm_extended_advertisements_enabled", "1", "Is plugin enabled?", 0, true, 0.0, true, 1.0);
	g_hAdvertDelay = CreateConVar("sm_extended_advertisements_delay", "30.0", "The delay time between each advertisement");
	g_hAdvertFile = CreateConVar("sm_extended_advertisements_file", "configs/extended_advertisements.txt", "What is the file directory of the advertisements file");
	g_hExitPanel = CreateConVar("sm_extended_advertisements_exitmenu", "1", "In \"M\" type menus, can clients close the menu with the press of any button?");
	g_hExtraTopColorsPath = CreateConVar("sm_extended_advertisement_extratopcolors_file", "configs/extra_top_colors.txt", "What is the directory of the \"Extra Top Colors\" config?");
	#if defined ADVERT_TF2COLORS
	g_hExtraChatColorsPath = CreateConVar("sm_extended_advertisements_extrachatcolors_file", "configs/extra_chat_colors.txt", "What is the directory of the \"Extra Chat Colors\" config?");
	#endif
	
	HookConVarChange(g_hPluginEnabled, OnEnableChange);
	HookConVarChange(g_hAdvertDelay, OnAdvertDelayChange);
	HookConVarChange(g_hAdvertFile, OnAdvertFileChange);
	HookConVarChange(g_hExitPanel, OnExitChange);
	HookConVarChange(g_hExtraTopColorsPath, OnExtraTopColorsPathChange);
	#if defined ADVERT_TF2COLORS
	HookConVarChange(g_hExtraChatColorsPath, OnExtraChatColorsPathChange);
	#endif
	
	InitiConfiguration();
	
	LoadTranslations("extended_advertisements.phrases");
	
	
	RegAdminCmd("sm_reloadads", Command_ReloadAds, ADMFLAG_ROOT);
	RegAdminCmd("sm_showad", Command_ShowAd, ADMFLAG_ROOT);
	
	
	AutoExecConfig();
	
	g_hForwardPreReplace = CreateGlobalForward("OnAdvertPreReplace", ET_Hook, Param_CellByRef, Param_String, Param_String, Param_CellByRef);
	g_hForwardPostAdvert = CreateGlobalForward("OnPostAdvertisementShown", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	g_hForwardPreClientReplace = CreateGlobalForward("OnAdvertPreClientReplace", ET_Single, Param_Cell, Param_Cell, Param_String, Param_String, Param_CellByRef);
	
	//g_hDynamicTagRegex = CompileRegex("\\{([Cc][Oo][Nn][Vv][Aa][Rr](_[Bb][Oo][Oo][Ll])?):[A-Za-z0-9_!@#$%^&*()\\-~`+=]{1,}\\}");
	
	g_bUseSteamTools = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Steam_GetPublicIP") == FeatureStatus_Available);
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

/**
 * 
 * Format Time
 * Note: Credit goes to GameME, this was a mere copy and paste
 * 
 */

 
 
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	g_bUseSteamTools = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Steam_GetPublicIP") == FeatureStatus_Available);
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_RemovePlugin();
	}
	
	g_bUseSteamTools = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Steam_GetPublicIP") == FeatureStatus_Available);
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
	InitiConfiguration();
	#if defined ADVERT_TF2COLORS
	parseExtraChatColors();
	#endif
	parseExtraTopColors();
	parseAdvertisements();
	if (g_bPluginEnabled)
	{
		g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}


stock InitiConfiguration()
{
	g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
	g_fAdvertDelay = GetConVarFloat(g_hAdvertDelay);
	g_bExitPanel = GetConVarBool(g_hExitPanel);
	
	decl String:advertPath[PLATFORM_MAX_PATH];
	GetConVarString(g_hAdvertFile, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strConfigPath, sizeof(g_strConfigPath), advertPath);
	
	GetConVarString(g_hExtraTopColorsPath, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strExtraTopColorsPath, sizeof(g_strExtraTopColorsPath), advertPath);
	
	#if defined ADVERT_TF2COLORS
	GetConVarString(g_hExtraChatColorsPath, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strExtraChatColorsPath, sizeof(g_strExtraChatColorsPath), advertPath);
	#endif
	initTopColorTrie();
}

public OnExtraTopColorsPathChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	BuildPath(Path_SM, g_strExtraTopColorsPath, sizeof(g_strExtraTopColorsPath), newValue);
	if (g_hTopColorTrie != INVALID_HANDLE)
		ClearTrie(g_hTopColorTrie);
	parseExtraTopColors();
}

public OnExitChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	g_bExitPanel = StringToInt(newValue) ? true : false;
}

#if defined ADVERT_TF2COLORS
public OnExtraChatColorsPathChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	BuildPath(Path_SM, g_strExtraChatColorsPath, sizeof(g_strExtraChatColorsPath), newValue);
	parseExtraChatColors();
}
#endif
public OnEnableChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	g_bPluginEnabled = StringToInt(newValue) ? true : false;
}

public OnAdvertDelayChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	g_fAdvertDelay = StringToFloat(newValue);
	g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnAdvertFileChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	BuildPath(Path_SM, g_strConfigPath, sizeof(g_strConfigPath), newValue);
	if (g_hAdvertisements != INVALID_HANDLE)
		CloseHandle(g_hAdvertisements);
	parseAdvertisements();
}

public Action:AdvertisementTimer(Handle:advertTimer)
{
	if (g_bPluginEnabled)
	{
		decl String:sFlags[32], String:sText[256], String:sType[6], String:sBuffer[256], String:strSectionName[128], String:noFlags[32];
		new flagBits = -1,
			noFlagBits = -1,
			sectionName;
		
		KvGetSectionName(g_hAdvertisements, strSectionName, sizeof(strSectionName));
		sectionName = StringToInt(strSectionName);
		KvGetString(g_hAdvertisements, "type",  sType,  sizeof(sType));
		KvGetString(g_hAdvertisements, "text",  sText,  sizeof(sText));
		KvGetString(g_hAdvertisements, "noflags", noFlags, sizeof(noFlags), "none");
		KvGetString(g_hAdvertisements, "flags", sFlags, sizeof(sFlags), "none");
		
		if (!KvGotoNextKey(g_hAdvertisements)) 
		{
			KvRewind(g_hAdvertisements);
			KvGotoFirstSubKey(g_hAdvertisements);
		}
		
		if (!StrEqual(sFlags, "none"))
			flagBits = ReadFlagString(sFlags);
		
		if (!StrEqual(noFlags, "none"))
			noFlagBits = ReadFlagString(noFlags);
		
		
		new Action:forwardReturn = Plugin_Continue,
			bool:forwardBool = true;
		Call_StartForward(g_hForwardPreReplace);
		Call_PushCellRef(sectionName);
		Call_PushStringEx(sType, sizeof(sType), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushStringEx(sText, sizeof(sText), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCellRef(flagBits);
		Call_Finish(_:forwardReturn);
		
		if (forwardReturn != Plugin_Continue)
			return Plugin_Continue;
		
		ReplaceAdText(sText, sText, sizeof(sText));
		strcopy(sBuffer, sizeof(sBuffer), sText);
		
		if (StrContains(sType, "C", false) != -1) 
		{
			String_RemoveExtraTags(sBuffer, sizeof(sBuffer));
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_Finish(_:forwardBool);
				
				if (forwardBool && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					PrintCenterText(client, sBuffer);	
					new Handle:hCenterAd;
					g_hCenterAd[client] = CreateDataTimer(1.0, Timer_CenterAd, hCenterAd, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
					WritePackCell(hCenterAd,   client);
					WritePackString(hCenterAd, sBuffer);
					
				}
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		forwardBool = true;
		if (StrContains(sType, "H", false) != -1) 
		{
			String_RemoveExtraTags(sBuffer, sizeof(sBuffer));
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_Finish(_:forwardBool);
				
				if (forwardBool && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					PrintHintText(client, sBuffer);
				}
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		forwardBool = true;
		if (StrContains(sType, "M", false) != -1) 
		{
			new Handle:hPl = CreatePanel();
			DrawPanelText(hPl, sBuffer);
			SetPanelCurrentKey(hPl, 10);
			
			String_RemoveExtraTags(sBuffer, sizeof(sBuffer));
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_Finish(_:forwardBool);
				
				if (forwardBool && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					SendPanelToClient(hPl, client, Handler_DoNothing, 10);
				}
			}
			
			CloseHandle(hPl);
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		forwardBool = true;
		if (StrContains(sType, "S", false) != -1) 
		{
			String_RemoveExtraTags(sBuffer, sizeof(sBuffer), true);
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_Finish(_:forwardBool);

				if (forwardBool && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					CPrintToChat(client, sBuffer);
				}
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		forwardBool = true;
		if (StrContains(sType, "T", false) != -1) 
		{
			// Credits go to Dr. Mckay
			decl String:part[256], String:find[32];
			new value[4], first, last;
			new index = 0;
			first = FindCharInString(sBuffer[index], '{');
			last = FindCharInString(sBuffer[index], '}');
			if (first != -1 || last != -1) 
			{
				first++;
				last--;
				for (new j = 0; j <= last - first + 1; j++) 
				{
					if (j == last - first + 1) 
					{
						part[j] = 0;
						break;
					}
					part[j] = sBuffer[index + first + j];
				}
				index += last + 2;
				String_ToLower(part, part, sizeof(part));
				if (g_hTopColorTrie == INVALID_HANDLE)
				{
					initTopColorTrie();
					parseExtraTopColors();
				}
				if (GetTrieArray(g_hTopColorTrie, part, value, 4)) 
				{
					Format(find, sizeof(find), "{%s}", part);
					ReplaceString(sBuffer, sizeof(sBuffer), find, "", false);
				}
			}
			else
			{
				GetTrieArray(g_hTopColorTrie, "white", value, 4);
			}
			
			String_RemoveExtraTags(sBuffer, sizeof(sBuffer));
			
			new Handle:hKv = CreateKeyValues("Stuff", "title", sBuffer);
			KvSetColor(hKv, "color", value[0], value[1], value[2], value[3]);
			KvSetNum(hKv,   "level", 1);
			KvSetNum(hKv,   "time",  10);
			
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_Finish(_:forwardBool);
				
				if (forwardBool && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer, sizeof(sBuffer));
					CreateDialog(client, hKv, DialogType_Msg);
				}
			}
			CloseHandle(hKv);
		}
		Call_StartForward(g_hForwardPostAdvert);
		Call_PushCell(sectionName);
		Call_PushString(sType);
		Call_PushString(sText);
		Call_PushCell(flagBits);
		Call_Finish();
	}
	return Plugin_Continue;
}

public Handler_DoNothing(Handle:menu, MenuAction:action, param1, param2) 
{
	if (g_bExitPanel)
	{
		switch (action)
		{
			case MenuAction_Select:
			{
				CloseHandle(menu);
			}
			case MenuAction_End:
			{
				CloseHandle(menu);
			}
		}
	}
}

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

public Action:Command_ShowAd(client, args)
{
	AdvertisementTimer(g_hAdvertTimer);
	return Plugin_Handled;
}

public Action:Command_ReloadAds(client, args)
{
	if (g_bPluginEnabled)
	{
		#if defined ADVERT_TF2COLORS
		parseExtraChatColors();
		#endif
		if (g_hTopColorTrie != INVALID_HANDLE)
			ClearTrie(g_hTopColorTrie);
		initTopColorTrie();
		parseExtraTopColors();
		if (g_hAdvertisements != INVALID_HANDLE)
			CloseHandle(g_hAdvertisements);
		parseAdvertisements();
		CPrintToChat(client, "%t %t", "Advert_Tag", "Config_Reloaded");
	}
	return Plugin_Handled;
}

stock parseAdvertisements()
{
	if (g_bPluginEnabled)
	{
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
	strcopy(outputText, outputText_maxLength, inputText);
	decl String:part[256], String:replace[128];
	new first, last;
	new index = 0, charIndex;
	new Handle:conVarFound;
	for (new i = 0; i < 100; i++) 
	{
		first = FindCharInString(outputText[index], '{');
		last = FindCharInString(outputText[index], '}');
		if (first != -1 || last != -1)
		{
			for (new j = 0; j <= last - first + 1; j++) 
			{
				if (j == last - first + 1) 
				{
					part[j] = 0;
					break;
				}
				part[j] = outputText[index + first + j];
			}
			index += last + 1;
			
			charIndex = StrContains(part, "{CONVAR:", false);
			if (charIndex == 0)
			{
				strcopy(replace, sizeof(replace), part);
				ReplaceString(replace, sizeof(replace), "{CONVAR:", "", false);
				ReplaceString(replace, sizeof(replace), "}", "", false);
				conVarFound = FindConVar(replace);
				if (conVarFound != INVALID_HANDLE)
				{
					GetConVarString(conVarFound, replace, sizeof(replace));
					ReplaceString(outputText, outputText_maxLength, part, replace, false);
				}
				else
					ReplaceString(outputText, outputText_maxLength, part, "", false);
			}
			else
			{
				charIndex = StrContains(part, "{CONVAR_BOOL:", false);
				if (charIndex == 0)
				{
					strcopy(replace, sizeof(replace), part);
					ReplaceString(replace, sizeof(replace), "{CONVAR_BOOL:", "", false);
					ReplaceString(replace, sizeof(replace), "}", "", false);
					conVarFound = FindConVar(replace);
					if (conVarFound != INVALID_HANDLE)
					{
						new int = GetConVarInt(conVarFound);
						if (int == 1 || int == 0)
							ReplaceString(outputText, outputText_maxLength, part, g_strConVarBoolText[int], false);
						else
							ReplaceString(outputText, outputText_maxLength, part, "", false);
					}
					else
						ReplaceString(outputText, outputText_maxLength, part, "", false);
				}
			}
			
			/*if (MatchRegex(g_hDynamicTagRegex, part) > 0)
			{
				strcopy(replace, sizeof(replace), part);
				new Handle:conVarFound = INVALID_HANDLE;
				if (StrContains(replace, "CONVAR_BOOL", false) != -1)
				{
					ReplaceString(replace, sizeof(replace), "{CONVAR_BOOL:", "", false);
					ReplaceString(replace, sizeof(replace), "}", "", false);
					conVarFound = FindConVar(replace);
					if (conVarFound != INVALID_HANDLE)
					{
						new conVarValue = GetConVarInt(conVarFound);
						if (conVarValue == 0 || conVarValue == 1)
							strcopy(replace, sizeof(replace), g_strConVarBoolText[conVarValue]);
						else
							replace = "";
					}
					else
						replace = "";
				}
				else
				{
					ReplaceString(replace, sizeof(replace), "{CONVAR:", "", false);
					ReplaceString(replace, sizeof(replace), "}", "", false);
					conVarFound = FindConVar(replace);
					if (conVarFound != INVALID_HANDLE)
						GetConVarString(conVarFound, replace, sizeof(replace));
					else
						replace = "";
				}
				ReplaceString(outputText, outputText_maxLength, part, replace);
			}*/
		}
		else
			break;
	}
	
	new i = 1;
	decl String:strTemp[256];
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetServerIP(strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetServerIP(strTemp, sizeof(strTemp), true);
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		Format(strTemp, sizeof(strTemp), "%i", Server_GetPort());
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetCurrentMap(strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetNextMap(strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		IntToString(g_iTickrate, strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		FormatTime(strTemp, sizeof(strTemp), "%I:%M:%S%p");
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		FormatTime(strTemp, sizeof(strTemp), "%H:%M:%S");
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		FormatTime(strTemp, sizeof(strTemp), "%x");
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		new iMins, iSecs, iTimeLeft;
			
		if (GetMapTimeLeft(iTimeLeft) && iTimeLeft > 0) 
		{
			iMins = iTimeLeft / 60;
			iSecs = iTimeLeft % 60;
		}
		
		Format(strTemp, sizeof(strTemp), "%d:%02d", iMins, iSecs);
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	strTemp[0] = '\0';
}

stock ReplaceClientText(client, const String:inputText[], String:outputText[], outputText_maxLength)
{
	
	if (Client_IsValid(client))
	{
		strcopy(outputText, outputText_maxLength, inputText);
		new i = 1;
		decl String:strTemp[256];
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientName(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientAuthString(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientIP(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientIP(client, strTemp, sizeof(strTemp), false);
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			Format(strTemp, sizeof(strTemp), "%d", GetClientTime(client));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			Format(strTemp, sizeof(strTemp), "%d", Client_GetMapTime(client));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		strTemp[0] = '\0';
	}
	return;
}

stock GetServerIP(String:ipAddress[], serverIP_maxLength, bool:fullIp = false)
{
	Server_GetIPNumString(ipAddress, serverIP_maxLength, g_bUseSteamTools);
	if (fullIp)
	{
		new serverPublicPort = Server_GetPort();
		Format(ipAddress, serverIP_maxLength, "%s:%i", ipAddress, serverPublicPort);
	}
}

public CanViewAdvert(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new clientFlagBits = GetNativeCell(2);
	new noFlagBits = GetNativeCell(3);
	if (clientFlagBits == -1 && noFlagBits == -1)
		return true;
	if (CheckCommandAccess(client, "extended_adverts", ADMFLAG_ROOT))
		return true;
	if ((clientFlagBits == -1 || CheckCommandAccess(client, "extended_advert", clientFlagBits)) && (noFlagBits == -1 || !CheckCommandAccess(client, "extended_notview", noFlagBits)))
		return true;
	return false;
}

#if defined ADVERT_TF2COLORS
stock parseExtraChatColors()
{
	if (g_bPluginEnabled)
	{
		if (FileExists(g_strExtraChatColorsPath)) 
		{
			new Handle:keyValues = CreateKeyValues("Extra Chat Colors");
			FileToKeyValues(keyValues, g_strExtraChatColorsPath);
			KvGotoFirstSubKey(keyValues);
			decl String:colorName[128], hex;
			do
			{
				KvGetSectionName(keyValues, colorName, sizeof(colorName));
				hex = KvGetNum(keyValues, "hex", 0);
				if (hex != 0)
					CAddColor(colorName, hex);
			}
			while (KvGotoNextKey(keyValues));
			KvRewind(keyValues);
		}
	}
}
#endif

stock parseExtraTopColors()
{
	if (g_bPluginEnabled)
	{
		if (FileExists(g_strExtraTopColorsPath)) 
		{
			new Handle:keyValues = CreateKeyValues("Extra Top Colors");
			FileToKeyValues(keyValues, g_strExtraTopColorsPath);
			KvGotoFirstSubKey(keyValues);
			decl String:colorName[128], red, green, blue, alpha;
			do
			{
				KvGetSectionName(keyValues, colorName, sizeof(colorName));
				String_ToLower(colorName, colorName, sizeof(colorName));
				red = KvGetNum(keyValues, "red");
				green = KvGetNum(keyValues, "green");
				blue = KvGetNum(keyValues, "blue");
				alpha = KvGetNum(keyValues, "alpha", 255);
				new rgba[4];
				rgba[0] = red;
				rgba[1] = green;
				rgba[2] = blue;
				rgba[3] = alpha;
				SetTrieArray(g_hTopColorTrie, colorName, rgba, 4);
			}
			while (KvGotoNextKey(keyValues));
			KvRewind(keyValues);
		}
	}
}

stock initTopColorTrie()
{
	g_hTopColorTrie = CreateTrie();
	SetTrieArray(g_hTopColorTrie, "white", {255, 255, 255, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "red", {255, 0, 0, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "green", {0, 255, 0, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "blue", {0, 0, 255, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "yellow", {255, 255, 0, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "purple", {255, 0, 255, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "cyan", {0, 255, 255, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "orange", {255, 128, 0, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "pink", {255, 0, 128, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "olive", {128, 255, 0, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "lime", {0, 255, 128, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "violet", {128, 0, 255, 255}, 4);
	SetTrieArray(g_hTopColorTrie, "lightblue", {0, 128, 255, 255}, 4);
}

stock removeTopColors(String:input[], maxlength, bool:ignoreChat = true)
{
	decl String:part[256], String:find[32];
	new value[4], first, last;
	new index = 0;
	new bool:result = false;
	for (new i = 0; i < 100; i++) 
	{
		result = false;
		first = FindCharInString(input[index], '{');
		last = FindCharInString(input[index], '}');
		if (first == -1 || last == -1) 
		{
			return;
		}
		first++;
		last--;
		for (new j = 0; j <= last - first + 1; j++) 
		{
			if(j == last - first + 1) 
			{
				part[j] = 0;
				break;
			}
			part[j] = input[index + first + j];
		}
		index += last + 2;
		String_ToLower(part, part, sizeof(part));
		#if defined ADVERT_TF2COLORS
		new value_ex;
		if (ignoreChat && (GetTrieValue(CTrie, part, value_ex) || !strcmp(part, "default", false) || !strcmp(part, "teamcolor", false)))
			result = true;
		#else
		if (ignoreChat)
		{
			decl String:colorTag[64];
			for (new x = 0; x < sizeof(CTag); x++)
			{
				Format(colorTag, sizeof(colorTag), "{%s}", CTag[x]);
				if (StrContains(part, colorTag, false) != -1)
					result = true;
			}
		}
		#endif
		if (g_hTopColorTrie == INVALID_HANDLE)
		{
			initTopColorTrie();
			parseExtraTopColors();
		}
		if (GetTrieArray(g_hTopColorTrie, part, value, 4) && !result) 
		{
			Format(find, sizeof(find), "{%s}", part);
			ReplaceString(input, maxlength, find, "", false);
		}
	}
}

stock String_RemoveExtraTags(String:inputString[], inputString_maxLength, bool:ignoreChat = false, bool:ignoreTop = false, bool:ignoreRawTag = false)
{
	if (!ignoreChat)
		CRemoveTags(inputString, inputString_maxLength);
	if (!ignoreTop)
		removeTopColors(inputString, inputString_maxLength, ignoreChat);
	if (!ignoreRawTag)
	{
		for (new i = 1; i < sizeof(g_tagRawText); i++)
		{
			if (StrContains(inputString, g_tagRawText[i], false) != -1)
				ReplaceString(inputString, inputString_maxLength, g_tagRawText[i], "", false);
		}
	}
}

/** 
 * 
 * Modified version of SMLIB's Server_GetIPString
 * 
 */

stock Server_GetIPNumString(String:ipBuffer[], ipBuffer_maxLength, bool:useSteamTools)
{
	new ip;
	switch (useSteamTools)
	{
		case true:
		{
			new octets[4];
			Steam_GetPublicIP(octets);
			ip =
				octets[0] << 24	|
				octets[1] << 16	|
				octets[2] << 8	|
				octets[3];
			LongToIP(ip, ipBuffer, ipBuffer_maxLength);
		}
		case false:
		{
			new Handle:conVarHostIP = INVALID_HANDLE;
			if (conVarHostIP == INVALID_HANDLE)
				conVarHostIP = FindConVar("hostip");
			ip = GetConVarInt(conVarHostIP);
			LongToIP(ip, ipBuffer, ipBuffer_maxLength);
		}
	}
}