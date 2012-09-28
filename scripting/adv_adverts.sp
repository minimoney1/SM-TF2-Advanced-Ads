#pragma semicolon 1
//Comment out this line if you want to use this on something other than tf2
#define ADVERT_SOURCE2009

#include <sourcemod>
#undef REQUIRE_EXTENSIONS
#include <steamtools>
#define REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN
#if defined ADVERT_SOURCE2009
#include <morecolors_ads>
#else
#include <colors_ads>
#endif
#include <regex>
#include <smlib>
#include <extended_adverts>

#define PLUGIN_VERSION "1.2.8"

#if defined ADVERT_SOURCE2009
#define UPDATE_URL "http://dl.dropbox.com/u/83581539/update-tf2.txt"
#else
#define UPDATE_URL "http://dl.dropbox.com/u/83581539/update-nontf2.txt"
#endif

new Handle:g_hPluginEnabled = INVALID_HANDLE;
new Handle:g_hFuncArray = INVALID_HANDLE;
new Handle:g_hDynamicTagArray = INVALID_HANDLE;
new Handle:g_hDynamicClientTagArray = INVALID_HANDLE;
new Handle:g_hClientTagArray = INVALID_HANDLE;
new Handle:g_hRootAccess = INVALID_HANDLE;
new Handle:g_hAdvertDelay = INVALID_HANDLE;
new Handle:g_hAdvertFile = INVALID_HANDLE;
new Handle:g_hAdvertisements = INVALID_HANDLE;
new Handle:g_hAdvertTimer = INVALID_HANDLE;
new Handle:g_hDynamicTagRegex = INVALID_HANDLE;
new Handle:g_hExitPanel = INVALID_HANDLE;
new Handle:g_hExtraTopColorsPath = INVALID_HANDLE;
#if defined ADVERT_SOURCE2009
new Handle:g_hExtraChatColorsPath = INVALID_HANDLE;
new String:g_strExtraChatColorsPath[PLATFORM_MAX_PATH];
#endif

new Handle:g_hCenterAd[MAXPLAYERS + 1];

new Handle:g_hTopColorTrie = INVALID_HANDLE;

new Handle:g_hForwardPreLoadPre,
	Handle:g_hForwardPreReplace,
	Handle:g_hForwardPreClientReplace,
	Handle:g_hForwardPostAdvert;
#if defined ADVERT_SOURCE2009	
new	Handle:g_hForwardPreAddChatColor,
	Handle:g_hForwardPostAddChatColor;
#endif
new	Handle:g_hForwardPreAddTopColor,
	Handle:g_hForwardPostAddTopColor,
	Handle:g_hForwardPreAddAdvert,
	Handle:g_hForwardPostAddAdvert,
	Handle:g_hForwardPreDeleteAdvert,
	Handle:g_hForwardOnLoadedPost,
	// Handle:g_hPrivateForwardTag,
	Handle:g_hForwardPostDeleteAdvert;

new bool:g_bPluginEnabled,
	bool:g_bExitPanel,
	bool:g_bUseSteamTools,
	bool:g_bRootAccess;

new Float:g_fAdvertDelay;


new bool:g_bTickrate = true;
new g_iTickrate;
new g_iFrames = 0;
new Float:g_fTime;
new String:g_strConfigPath[PLATFORM_MAX_PATH];
new String:g_strExtraTopColorsPath[PLATFORM_MAX_PATH];

static const String:g_tagRawText[11][24] = 
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

static const String:g_clientRawText[7][32] =
{
	"",
	"{CLIENT_NAME}",
	"{CLIENT_STEAMID}",
	"{CLIENT_IP}",
	"{CLIENT_FULLIP}",
	"{CLIENT_CONNECTION_TIME}",
	"{CLIENT_MAPTIME}"
};

static const String:g_strConVarBoolText[2][5] =
{
	"OFF",
	"ON"
};

static const String:g_strKeyValueKeyList[4][8] =
{
	"type",
	"text",
	"flags",
	"noflags"
};

public Plugin:myinfo = 
{
	name        = "Extended Advertisements",
	author      = "Mini",
	description = "Extended advertisement system for Source 2009 games' new color abilities for developers",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("adv_adverts");
	MarkNativeAsOptional("Steam_GetPublicIP");
	MarkNativeAsOptional("Updater_AddPlugin");
	MarkNativeAsOptional("Updater_RemovePlugin");
	CreateNative("AddExtraTag", Native_AddExtraTag);
	CreateNative("AddExtraClientTag", Native_AddExtraClientTag);
	CreateNative("AddExtraDynamicTag", Native_AddDynamicExtraTag);
	CreateNative("AddExtraDynamicClientTag", Native_AddDynamicExtraClientTag);
	CreateNative("AddExtraTopColor", Native_AddTopColorToTrie);
	CreateNative("Client_CanViewAds", Native_CanViewAdvert);
	CreateNative("AddAdvert", Native_AddAdvert);
	CreateNative("ShowAdvert", Native_ShowAdvert);
	CreateNative("ReloadAdverts", Native_ReloadAds);
	CreateNative("DeleteAdvert", Native_DeleteAdvert);
	CreateNative("AdvertExists", Native_AdvertExists);
	CreateNative("GetAdvertInfo", Native_GetAdvertInfo);
	CreateNative("GetNumAdverts", Native_GetNumAdverts);
	CreateNative("GetRandomAdvert", Native_GetRandomAdvert);
	CreateNative("JumpToAdvert", Native_JumpToAdvert);
	#if defined ADVERT_SOURCE2009
	CreateNative("AddExtraChatColor", Native_AddChatColorToTrie);
	#endif
	return APLRes_Success;
}

public Native_JumpToAdvert(Handle:plugin, numParams)
{
	decl String:id[128];
	GetNativeString(1, id, sizeof(id));
	return (KvJumpToKey(g_hAdvertisements, id));
}

public Native_GetRandomAdvert(Handle:plugin, numParams)
{
	new maxlength = GetNativeCell(2);
	decl String:id[maxlength+2];
	new advertNum = GetNumAdverts(),
		random = GetRandomInt(0, advertNum);
	KvSavePosition(g_hAdvertisements);
	KvGoBack(g_hAdvertisements);
	KvGotoFirstSubKey(g_hAdvertisements);
	for (new i = 0; i <= advertNum; i++)
	{
		if (i == random)
		{
			KvGetSectionName(g_hAdvertisements, id, maxlength);
			SetNativeString(1, id, maxlength);
			KvRewind(g_hAdvertisements);
			return true;
		}
		KvGotoNextKey(g_hAdvertisements);
	}
	KvRewind(g_hAdvertisements);
	return false;
}

public Native_GetNumAdverts(Handle:plugin, numParams)
{
	new i = 0;
	KvSavePosition(g_hAdvertisements);
	KvGoBack(g_hAdvertisements);
	KvGotoFirstSubKey(g_hAdvertisements);
	while (KvGotoNextKey(g_hAdvertisements))
	{
		i++;
	}
	KvRewind(g_hAdvertisements);
	return i;
}

public Native_AddDynamicExtraTag(Handle:plugin, numParams)
{
	decl String:pattern[512];
	GetNativeString(1, pattern, sizeof(pattern));
	new Function:func = GetNativeCell(2);
	PushArrayString(g_hDynamicTagArray, pattern);
	PushArrayCell(g_hDynamicTagArray, _:func);
	PushArrayCell(g_hDynamicTagArray, plugin);
	PushArrayCell(g_hDynamicTagArray, GetNativeCell(3));
}

public Native_AddDynamicExtraClientTag(Handle:plugin, numParams)
{
	decl String:pattern[512];
	GetNativeString(1, pattern, sizeof(pattern));
	new Function:func = GetNativeCell(2);
	PushArrayString(g_hDynamicClientTagArray, pattern);
	PushArrayCell(g_hDynamicClientTagArray, _:func);
	PushArrayCell(g_hDynamicClientTagArray, plugin);
	PushArrayCell(g_hDynamicClientTagArray, GetNativeCell(3));
}

public Native_GetAdvertInfo(Handle:plugin, numParams)
{
	decl String:advertId[64];
	GetNativeString(1, advertId, sizeof(advertId));
	if (!AdvertExists(advertId))
		return false;
	KvSavePosition(g_hAdvertisements);
	new atype_ml = GetNativeCell(3),
	atext_ml = GetNativeCell(5),
	aflags_ml = GetNativeCell(7),
	anoflags_ml = GetNativeCell(9);
	decl String:aType[atype_ml];
	KvGetString(g_hAdvertisements, "type", aType, atype_ml);
	SetNativeString(2, aType, atype_ml);
	decl String:aText[atext_ml];
	KvGetString(g_hAdvertisements, "text", aText, atext_ml);
	SetNativeString(4, aText, atext_ml);
	decl String:aFlags[aflags_ml];
	KvGetString(g_hAdvertisements, "flags", aFlags, aflags_ml);
	SetNativeString(6, aFlags, aflags_ml);
	decl String:aNoFlags[anoflags_ml];
	KvGetString(g_hAdvertisements, "noflags", aNoFlags, anoflags_ml);
	SetNativeString(8, aNoFlags, anoflags_ml);
	return true;
}

public Native_AddExtraClientTag(Handle:plugin, numParams)
{
	decl String:tag[128];
	GetNativeString(1, tag, sizeof(tag));
	String_ToLower(tag, tag, sizeof(tag));
	if (tag[0] != '{' && tag[strlen(tag) - 1] != '}')
		Format(tag, sizeof(tag), "{%s}", tag);
	new Function:func = GetNativeCell(2);
	PushArrayString(g_hClientTagArray, tag);
	PushArrayCell(g_hClientTagArray, _:func);
	PushArrayCell(g_hClientTagArray, plugin);
}

public Native_AddExtraTag(Handle:plugin, numParams)
{
	decl String:tag[128];
	GetNativeString(1, tag, sizeof(tag));
	String_ToLower(tag, tag, sizeof(tag));
	if (tag[0] != '{' && tag[strlen(tag) - 1] != '}')
		Format(tag, sizeof(tag), "{%s}", tag);
	new Function:func = GetNativeCell(2);
	PushArrayString(g_hFuncArray, tag);
	PushArrayCell(g_hFuncArray, _:func);
	PushArrayCell(g_hFuncArray, plugin);
}

public Native_AdvertExists(Handle:plugin, numParams)
{
	decl String:id[32];
	GetNativeString(1, id, sizeof(id));
	KvSavePosition(g_hAdvertisements);
	if (KvJumpToKey(g_hAdvertisements, id))
	{
		KvRewind(g_hAdvertisements);
		return true;
	}
	return false;
}

public Native_DeleteAdvert(Handle:plugin, numParams)
{
	decl String:id[32];
	GetNativeString(1, id, sizeof(id));
	
	new Action:returnVal = Plugin_Continue;
	Call_StartForward(g_hForwardPreDeleteAdvert);
	Call_PushStringEx(id, sizeof(id), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(id));
	Call_Finish(_:returnVal);
	
	if (returnVal == Plugin_Handled || returnVal == Plugin_Stop)
		return false;
	
	KvSavePosition(g_hAdvertisements);
	if (KvJumpToKey(g_hAdvertisements, id))
	{
		KvGotoFirstSubKey(g_hAdvertisements);
		KvDeleteThis(g_hAdvertisements);
		KvRewind(g_hAdvertisements);
		Call_StartForward(g_hForwardPostDeleteAdvert);
		Call_PushString(id);
		Call_Finish();
		return true;
	}
	return false;
}
public Native_ReloadAds(Handle:plugin, numParams)
{
	new bool:ads = GetNativeCell(1),
		bool:tsay = GetNativeCell(2);
#if defined ADVERT_SOURCE2009	
	new bool:chat = GetNativeCell(3);
#endif
	if (ads)
	{
		if (g_hAdvertisements != INVALID_HANDLE)
			CloseHandle(g_hAdvertisements);
		parseAdvertisements();
	}
	if (tsay)
	{
		if (g_hTopColorTrie != INVALID_HANDLE)
			ClearTrie(g_hTopColorTrie);
		initTopColorTrie();
		parseExtraTopColors();
	}
#if defined ADVERT_SOURCE2009
	if (chat)
	{
		parseExtraChatColors();
	}
#endif
}

public Native_ShowAdvert(Handle:plugin, numParams)
{
	decl String:advertId[32];
	GetNativeString(1, advertId, sizeof(advertId));
	new bool:order = GetNativeCell(2);
	if (order)
		KvSavePosition(g_hAdvertisements);
	if (strcmp(advertId, NULL_STRING, false) != 0)
	{
		if (!KvJumpToKey(g_hAdvertisements, advertId))
			return false;
	}
	AdvertisementTimer(g_hAdvertTimer);
	if (order)
		KvRewind(g_hAdvertisements);
	return true;
}

public Native_AddAdvert(Handle:plugin, numParams)
{
	decl String:advertId[32];
	advertId[0] = '\0';
	GetNativeString(1, advertId, sizeof(advertId));
	if (!strcmp(advertId, "") || !strcmp(advertId, "none", false))
	{
		new numAdverts = GetNumAdverts();
		KvSavePosition(g_hAdvertisements);
		new i = 1;
		do
		{
			i++;
			FormatEx(advertId, sizeof(advertId), "%i", (numAdverts + i));
		}
		while (KvJumpToKey(g_hAdvertisements, advertId));
		KvRewind(g_hAdvertisements);
	}
	decl String:advertText[512], String:advertType[16];
	advertText[0] = '\0';
	advertType[0] = '\0';
	GetNativeString(3, advertText, sizeof(advertText));
	GetNativeString(2, advertType, sizeof(advertType));
	decl String:flagBits[32];
	decl String:noFlagBits[32];
	flagBits[0] = '\0';
	noFlagBits[0] = '\0';
	GetNativeString(4, flagBits, sizeof(flagBits));
	GetNativeString(5, noFlagBits, sizeof(noFlagBits));
	new bool:jumpTo = GetNativeCell(6);
	new bool:replace = GetNativeCell(7);
	
	new Action:returnVal = Plugin_Continue;
	
	Call_StartForward(g_hForwardPreAddAdvert);
	Call_PushStringEx(advertId, sizeof(advertId), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(advertId));
	Call_PushStringEx(advertType, sizeof(advertType), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(advertType));
	Call_PushStringEx(advertText, sizeof(advertType), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(advertText));
	Call_PushStringEx(flagBits, sizeof(flagBits), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(flagBits));
	Call_PushStringEx(noFlagBits, sizeof(noFlagBits), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(noFlagBits));
	Call_PushCellRef(jumpTo);
	Call_PushCellRef(replace);
	Call_Finish(_:returnVal);
	
	if (returnVal == Plugin_Handled || returnVal == Plugin_Stop)
		return false;
	
	new bool:advertExists = AdvertExists(advertId);
	
	if (!replace && advertExists)
	{
		if (jumpTo)
		{
			KvJumpToKey(g_hAdvertisements, advertId);
			KvGotoFirstSubKey(g_hAdvertisements);
		}
		return false;
	}

	if (!jumpTo)
		KvSavePosition(g_hAdvertisements);
	
	if (replace && advertExists)
	{
		KvJumpToKey(g_hAdvertisements, advertId);
		KvGotoFirstSubKey(g_hAdvertisements);
		KvDeleteThis(g_hAdvertisements);
	}
	
	KvJumpToKey(g_hAdvertisements, advertId, true);
	KvGotoFirstSubKey(g_hAdvertisements);

	KvSetString(g_hAdvertisements, g_strKeyValueKeyList[0], advertType);
	KvSetString(g_hAdvertisements, g_strKeyValueKeyList[1], advertText);
	KvSetString(g_hAdvertisements, g_strKeyValueKeyList[2], flagBits);
	KvSetString(g_hAdvertisements, g_strKeyValueKeyList[3], noFlagBits);
	
	if (!jumpTo)
		KvRewind(g_hAdvertisements);
	else
		KvGoBack(g_hAdvertisements);

	Call_StartForward(g_hForwardPostAddAdvert);
	Call_PushString(advertId);
	Call_PushString(advertType);
	Call_PushString(advertText);
	Call_PushString(flagBits);
	Call_PushString(noFlagBits);
	Call_PushCell(jumpTo);
	Call_PushCell(replace);
	Call_Finish();
	
	SetNativeString(1, advertId, sizeof(advertId));

	return true;
}

public Native_AddTopColorToTrie(Handle:plugin, numParams)
{
	decl String:colorName[64];
	GetNativeString(1, colorName, sizeof(colorName));
	new red = GetNativeCell(2),
		blue = GetNativeCell(3),
		green = GetNativeCell(4),
		alpha = GetNativeCell(5);
	new bool:replace = GetNativeCell(6);
	
	new Action:fReturn = Plugin_Continue;
	Call_StartForward(g_hForwardPreAddTopColor);
	Call_PushStringEx(colorName, sizeof(colorName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(colorName));
	Call_PushCellRef(red);
	Call_PushCellRef(green);
	Call_PushCellRef(blue);
	Call_PushCellRef(alpha);
	Call_PushCellRef(replace);
	Call_Finish(_:fReturn);
	
	if (fReturn == Plugin_Handled || fReturn == Plugin_Stop)
	{
		return false;
	}
	
	new color[4];
	color[0] = red;
	color[1] = blue;
	color[2] = green;
	color[3] = alpha;
	
	new returnVal = SetTrieArray(g_hTopColorTrie, colorName, color, 4, replace);
	
	Call_StartForward(g_hForwardPostAddTopColor);
	Call_PushString(colorName);
	Call_PushCell(red);
	Call_PushCell(green);
	Call_PushCell(blue);
	Call_PushCell(alpha);
	Call_PushCell(replace);
	Call_Finish();
	
	return returnVal;
}

#if defined ADVERT_SOURCE2009
public Native_AddChatColorToTrie(Handle:plugin, numParams)
{
	decl String:colorName[32];
	GetNativeString(1, colorName, sizeof(colorName));
	new hex = GetNativeCell(2);
	
	new Action:callReturn = Plugin_Continue;
	Call_StartForward(g_hForwardPreAddChatColor);
	Call_PushStringEx(colorName, sizeof(colorName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(colorName));
	Call_PushCellRef(hex);
	Call_Finish(_:callReturn);
	
	if (callReturn == Plugin_Handled || callReturn == Plugin_Stop)
		return false;
	
	new bool:returnVal = CAddColor(colorName, hex);
	
	Call_StartForward(g_hForwardPostAddChatColor);
	Call_PushString(colorName);
	Call_PushCell(hex);
	Call_Finish();
	
	return returnVal;
}
#endif

public OnPluginStart()
{
	CreateConVar("extended_advertisements_version", PLUGIN_VERSION, "Display advertisements", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	#if defined ADVERT_SOURCE2009
	if (!IsGameCompatible())
		SetFailState("[Extended Advertisements] You are running a version of this plugin that is incompatible with your game.");
	#endif
	g_hPluginEnabled = CreateConVar("sm_extended_advertisements_enabled", "1", "Is plugin enabled?", 0, true, 0.0, true, 1.0);
	g_hAdvertDelay = CreateConVar("sm_extended_advertisements_delay", "30.0", "The delay time between each advertisement");
	g_hAdvertFile = CreateConVar("sm_extended_advertisements_file", "configs/extended_advertisements.txt", "What is the file directory of the advertisements file");
	g_hExitPanel = CreateConVar("sm_extended_advertisements_exitmenu", "1", "In \"M\" type menus, can clients close the menu with the press of any button?");
	g_hExtraTopColorsPath = CreateConVar("sm_extended_advertisement_extratopcolors_file", "configs/extra_top_colors.txt", "What is the directory of the \"Extra Top Colors\" config?");
	#if defined ADVERT_SOURCE2009
	g_hExtraChatColorsPath = CreateConVar("sm_extended_advertisements_extrachatcolors_file", "configs/extra_chat_colors.txt", "What is the directory of the \"Extra Chat Colors\" config?");
	#endif
	g_hRootAccess = CreateConVar("sm_extended_advertisements_root_access", "0", "Will ROOT admins always see all ads?", 0, true, 0.0, true, 1.0);
	
	HookConVarChange(g_hPluginEnabled, OnEnableChange);
	HookConVarChange(g_hAdvertDelay, OnAdvertDelayChange);
	HookConVarChange(g_hAdvertFile, OnAdvertFileChange);
	HookConVarChange(g_hExitPanel, OnExitChange);
	HookConVarChange(g_hExtraTopColorsPath, OnExtraTopColorsPathChange);
	#if defined ADVERT_SOURCE2009
	HookConVarChange(g_hExtraChatColorsPath, OnExtraChatColorsPathChange);
	#endif
	HookConVarChange(g_hRootAccess, OnRootAccessChange);
	
	LoadTranslations("extended_advertisements.phrases");
	
	g_hFuncArray = CreateArray(128);
	g_hClientTagArray = CreateArray(128);
	g_hDynamicTagArray = CreateArray(256);
	g_hDynamicClientTagArray = CreateArray(256);	
	
	RegAdminCmd("sm_reloadads", Command_ReloadAds, ADMFLAG_RCON);
	RegAdminCmd("sm_showad", Command_ShowAd, ADMFLAG_RCON);
	RegAdminCmd("sm_addadvert", Command_AddAdvert, ADMFLAG_RCON);
	RegAdminCmd("sm_deladd", Command_DeleteAdvert, ADMFLAG_RCON);
	RegAdminCmd("sm_dumpads", Command_DumpAds, ADMFLAG_RCON);
	
	
	AutoExecConfig();
	
	g_hForwardOnLoadedPost = CreateGlobalForward("OnAdvertsLoaded", ET_Ignore);

	g_hForwardPreLoadPre = CreateGlobalForward("OnAdvertPreLoadPre", ET_Hook);
	g_hForwardPreReplace = CreateGlobalForward("OnAdvertPreReplace", ET_Hook, Param_String, Param_String, Param_String, Param_CellByRef, Param_CellByRef);
	g_hForwardPostAdvert = CreateGlobalForward("OnPostAdvertisementShown", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell, Param_Cell);
	g_hForwardPreClientReplace = CreateGlobalForward("OnAdvertPreClientReplace", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_CellByRef, Param_CellByRef);
#if defined ADVERT_SOURCE2009	
	g_hForwardPreAddChatColor = CreateGlobalForward("OnAddChatColorPre", ET_Hook, Param_String, Param_Cell, Param_CellByRef);
	g_hForwardPostAddChatColor = CreateGlobalForward("OnAddChatColorPost", ET_Ignore, Param_String, Param_Cell);
#endif
	g_hForwardPreAddTopColor = CreateGlobalForward("OnAddTopColorPre", ET_Hook, Param_String, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	g_hForwardPostAddTopColor = CreateGlobalForward("OnAddTopColorPost", ET_Ignore, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardPreAddAdvert = CreateGlobalForward("OnAddAdvertPre", ET_Hook, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_CellByRef, Param_CellByRef);
	g_hForwardPostAddAdvert = CreateGlobalForward("OnAddAdvertPost", ET_Ignore, Param_String, Param_String, Param_String, Param_String, Param_String, Param_Cell, Param_Cell);
	g_hForwardPreDeleteAdvert = CreateGlobalForward("OnPreDeleteAdvert", ET_Hook, Param_String, Param_Cell);
	g_hForwardPostDeleteAdvert = CreateGlobalForward("OnPostDeleteAdvert", ET_Ignore, Param_String);
	//g_hPrivateForwardTag = CreateForward(ET_Hook, Param_String, Param_String, Param_String);
	
	g_hDynamicTagRegex = CompileRegex("\\{([Cc][Oo][Nn][Vv][Aa][Rr](_[Bb][Oo][Oo][Ll])?):([A-Za-z0-9_!@#$%^&*()\\-~`+=]+\\})", PCRE_CASELESS|PCRE_UNGREEDY);
	
	g_bUseSteamTools = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Steam_GetPublicIP") == FeatureStatus_Available);
	
	InitiConfiguration();
	#if defined ADVERT_SOURCE2009
	parseExtraChatColors();
	#endif
	parseExtraTopColors();
	parseAdvertisements();
	Call_StartForward(g_hForwardOnLoadedPost);
	Call_Finish();

	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);
}

#if defined ADVERT_SOURCE2009
stock bool:IsGameCompatible()
{
	decl String:name[32];
	GetGameFolderName(name, sizeof(name));
	if (!strcmp(name, "cstrike") || !strcmp(name, "tf") || !strcmp(name, "hl2mp") || !strcmp(name, "dod"))
		return true;
	return false;
}
#endif

public Action:Command_DumpAds(client, args)
{
	decl String:file[256];
	BuildPath(Path_SM, file, sizeof(file), "configs/dump_ads.txt");
	OpenFile(file, "w");
	KvSavePosition(g_hAdvertisements);
	KvGoBack(g_hAdvertisements);
	KeyValuesToFile(g_hAdvertisements, file);
	KvRewind(g_hAdvertisements);
	ReplyToCommand(client, "%t %t", "Advert_Tag", "Dumped_Ads");
	return Plugin_Handled;
}

// [SM] Usage: sm_deladvert <Advert Id>
public Action:Command_DeleteAdvert(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Del_Usage");
		return Plugin_Handled;
	}
	decl String:arg[256];
	GetCmdArgString(arg, sizeof(arg));
	StripQuotes(arg);
	if (DeleteAdvert(arg))
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Del_Success", arg);
	else
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Del_Fail", arg);
	return Plugin_Handled;
}

// [SM] Usage: sm_addadvert <Advert Id> <Advert Type> <Advert Text> [Flags] [NoFlags]
public Action:Command_AddAdvert(client, args)
{
	
	if (args < 7)
	{
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Add_Usage");
		return Plugin_Handled;
	}
	decl String:arg[7][256];
	for (new i = 0; i < args; i++)
	{
		GetCmdArg((i + 1), arg[i], sizeof(arg[]));
		//PrintToChatAll("Got %s", arg[i]);
	}
	if (AddAdvert(arg[0], arg[1], arg[2], arg[3], arg[4], (StringToInt(arg[5]) ? true : false), (StringToInt(arg[6]) ? true : false)))
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Add_Success", arg[0]);
	else
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Add_Fail", arg[0]);

	ReloadAdverts();
	return Plugin_Handled;
}

/**
 * 
 * Format Time
 * Note: Credit goes to GameME, this was a mere copy and paste
 * 
 */

stock format_time(timestamp, String: formatted_time[192]) 
{ 
	Format(formatted_time, 192, "%dd %02d:%02d:%02dh", 
			timestamp / 86400, 
			timestamp / 3600 % 24, 
			timestamp / 60 % 60, 
			timestamp % 60 
		); 
}
 
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL);
	
	g_bUseSteamTools = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Steam_GetPublicIP") == FeatureStatus_Available);
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "updater"))
		Updater_RemovePlugin();
	
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
	#if defined ADVERT_SOURCE2009
	parseExtraChatColors();
	#endif
	parseExtraTopColors();
	parseAdvertisements();
	if (!g_bPluginEnabled)
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
	}
	else
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
		g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer, _, TIMER_REPEAT);
	}
}

public OnMapStart()
{
	if (!g_bPluginEnabled)
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
	}
	else
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
		g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer, _, TIMER_REPEAT);
	}
}

public OnMapEnd()
{
	if (g_hAdvertTimer != INVALID_HANDLE)
	{
		KillTimer(g_hAdvertTimer);
		g_hAdvertTimer = INVALID_HANDLE;
	}
}

stock InitiConfiguration()
{
	g_bPluginEnabled = GetConVarBool(g_hPluginEnabled);
	g_fAdvertDelay = GetConVarFloat(g_hAdvertDelay);
	g_bExitPanel = GetConVarBool(g_hExitPanel);
	g_bRootAccess = GetConVarBool(g_hRootAccess);

	decl String:advertPath[PLATFORM_MAX_PATH];
	GetConVarString(g_hAdvertFile, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strConfigPath, sizeof(g_strConfigPath), advertPath);
	
	GetConVarString(g_hExtraTopColorsPath, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strExtraTopColorsPath, sizeof(g_strExtraTopColorsPath), advertPath);
	
	#if defined ADVERT_SOURCE2009
	GetConVarString(g_hExtraChatColorsPath, advertPath, sizeof(advertPath));
	BuildPath(Path_SM, g_strExtraChatColorsPath, sizeof(g_strExtraChatColorsPath), advertPath);
	#endif
	initTopColorTrie();
}

public OnRootAccessChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	g_bRootAccess = StringToInt(newValue) ? true : false;
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

#if defined ADVERT_SOURCE2009
public OnExtraChatColorsPathChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	BuildPath(Path_SM, g_strExtraChatColorsPath, sizeof(g_strExtraChatColorsPath), newValue);
	parseExtraChatColors();
}
#endif
public OnEnableChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	new bool:newVal = StringToInt(newValue) ? true : false,
		bool:oldVal = StringToInt(oldValue) ? true : false;
	g_bPluginEnabled = newVal;
	if (newVal != oldVal)
	{
		if (!newVal)
		{
			if (g_hAdvertTimer != INVALID_HANDLE)
			{
				KillTimer(g_hAdvertTimer);
				g_hAdvertTimer = INVALID_HANDLE;
			}
		}
		else
		{
			if (g_hAdvertTimer != INVALID_HANDLE)
			{
				KillTimer(g_hAdvertTimer);
				g_hAdvertTimer = INVALID_HANDLE;
			}
			g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer, _, TIMER_REPEAT);
		}
	}
}

public OnAdvertDelayChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	g_fAdvertDelay = StringToFloat(newValue);
	
	if (!g_bPluginEnabled)
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
	}
	else
	{
		if (g_hAdvertTimer != INVALID_HANDLE)
		{
			KillTimer(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
		g_hAdvertTimer = CreateTimer(g_fAdvertDelay, AdvertisementTimer, _, TIMER_REPEAT);
	}
}

public OnAdvertFileChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	BuildPath(Path_SM, g_strConfigPath, sizeof(g_strConfigPath), newValue);
	if (g_hAdvertisements != INVALID_HANDLE)
	{
		CloseHandle(g_hAdvertisements);
		g_hAdvertisements = INVALID_HANDLE;
	}
	parseAdvertisements();
}

public Action:AdvertisementTimer(Handle:advertTimer)
{
	if (g_bPluginEnabled)
	{
		new Action:forwardReturn = Plugin_Continue;
		Call_StartForward(g_hForwardPreLoadPre);
		Call_Finish(_:forwardReturn);
		if (forwardReturn == Plugin_Handled || forwardReturn == Plugin_Stop)
			return Plugin_Continue;

		decl String:sFlags[32], String:sText[512], String:sType[6], String:sBuffer[256], String:sBuffer2[256], String:sBuffer3[256], String:sectionName[128];
		new flagBits = -1,
			noFlagBits = -1;
		
		KvGetSectionName(g_hAdvertisements, sectionName, sizeof(sectionName));
		KvGetString(g_hAdvertisements, g_strKeyValueKeyList[0],  sType,  sizeof(sType), "");
		KvGetString(g_hAdvertisements, g_strKeyValueKeyList[1],  sText,  sizeof(sText), "");
		KvGetString(g_hAdvertisements, g_strKeyValueKeyList[2], sFlags, sizeof(sFlags), "");
		if (!StrEqual(sFlags, ""))
			flagBits = ReadFlagString(sFlags);
		KvGetString(g_hAdvertisements, g_strKeyValueKeyList[3], sFlags, sizeof(sFlags), "");
		if (!StrEqual(sFlags, ""))
			noFlagBits = ReadFlagString(sFlags);
		
		if (!KvGotoNextKey(g_hAdvertisements)) 
		{
			KvRewind(g_hAdvertisements);
			KvGotoFirstSubKey(g_hAdvertisements);
		}

		if (StrContains(sText, "\\n") != -1)
		{
			Format(sFlags, sizeof(sFlags), "%c", 13);
			ReplaceString(sText, sizeof(sText), "\\n", sFlags);
		}

		Call_StartForward(g_hForwardPreReplace);
		Call_PushString(sectionName);
		Call_PushStringEx(sType, sizeof(sType), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushStringEx(sText, sizeof(sText), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCellRef(flagBits);
		Call_PushCellRef(noFlagBits);
		Call_Finish(_:forwardReturn);
		
		if (forwardReturn == Plugin_Handled || forwardReturn == Plugin_Stop)
			return Plugin_Continue;
		
		ReplaceAdText(sText, sText, sizeof(sText));
		strcopy(sBuffer, sizeof(sBuffer), sText);
		
		if (StrContains(sType, "C", false) != -1) 
		{			
			strcopy(sBuffer3, sizeof(sBuffer3), sBuffer);
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				forwardReturn = Plugin_Continue;
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(advType_Center);
				Call_PushString(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_PushCellRef(noFlagBits);
				Call_Finish(_:forwardReturn);
				
				if (IsPassedFwd(forwardReturn) && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer2, sizeof(sBuffer2));
					String_RemoveExtraTags(sBuffer2, sizeof(sBuffer2));
					PrintCenterText(client, sBuffer2);	
					new Handle:hCenterAd;
					g_hCenterAd[client] = CreateDataTimer(1.0, Timer_CenterAd, hCenterAd, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
					WritePackCell(hCenterAd,   GetClientUserId(client));
					WritePackString(hCenterAd, sBuffer2);
				}
				strcopy(sBuffer, sizeof(sBuffer), sBuffer3);
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		if (StrContains(sType, "H", false) != -1) 
		{			
			strcopy(sBuffer3, sizeof(sBuffer3), sBuffer);
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				forwardReturn = Plugin_Continue;
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(advType_Hint);
				Call_PushString(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_PushCellRef(noFlagBits);
				Call_Finish(_:forwardReturn);
				
				if (IsPassedFwd(forwardReturn) && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer2, sizeof(sBuffer2));
					String_RemoveExtraTags(sBuffer2, sizeof(sBuffer2));
					PrintHintText(client, sBuffer2);
				}
				strcopy(sBuffer, sizeof(sBuffer), sBuffer3);
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		if (StrContains(sType, "M", false) != -1) 
		{	
			strcopy(sBuffer3, sizeof(sBuffer3), sBuffer);
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				forwardReturn = Plugin_Continue;
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(advType_Menu);
				Call_PushString(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_PushCellRef(noFlagBits);
				Call_Finish(_:forwardReturn);
				
				if (IsPassedFwd(forwardReturn) && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer2, sizeof(sBuffer2));
					String_RemoveExtraTags(sBuffer2, sizeof(sBuffer2));
					new Handle:hPl = CreatePanel();
					DrawPanelText(hPl, sBuffer);
					if (g_bExitPanel)
					{
						DrawPanelText(hPl, " \n \n \n");
						DrawPanelItem(hPl, " Exit");
					}

					SetPanelCurrentKey(hPl, 10);
					SendPanelToClient(hPl, client, Handler_DoNothing, 10);
					CloseHandle(hPl);
				}
				strcopy(sBuffer, sizeof(sBuffer), sBuffer3);
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		if (StrContains(sType, "S", false) != -1) 
		{
			strcopy(sBuffer3, sizeof(sBuffer3), sBuffer);
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				forwardReturn = Plugin_Continue;
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(advType_Say);
				Call_PushString(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_PushCellRef(noFlagBits);
				Call_Finish(_:forwardReturn);

				if (IsPassedFwd(forwardReturn) && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer2, sizeof(sBuffer2));
					String_RemoveExtraTags(sBuffer2, sizeof(sBuffer2), true);
					CPrintToChatEx(client, client, sBuffer2);
				}
				strcopy(sBuffer, sizeof(sBuffer), sBuffer3);
			}
		}
		
		strcopy(sBuffer, sizeof(sBuffer), sText);
		if (StrContains(sType, "T", false) != -1) 
		{
			// Credits go to Dr. Mckay
			decl String:part[256], String:find[32];
			new value[4], first, last;
			new index = 0;
			first = FindCharInString(sBuffer[index], '{');
			last = FindCharInString(sBuffer[index], '}');
			if (first != -1 && last != -1) 
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
						
			strcopy(sBuffer3, sizeof(sBuffer3), sBuffer);
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH)
			{
				forwardReturn = Plugin_Continue;
				Call_StartForward(g_hForwardPreClientReplace);
				Call_PushCell(client);
				Call_PushCell(advType_Top);
				Call_PushString(sectionName);
				Call_PushString(sType);
				Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCellRef(flagBits);
				Call_PushCellRef(noFlagBits);
				Call_Finish(_:forwardReturn);
				
				if (IsPassedFwd(forwardReturn) && Client_CanViewAds(client, flagBits, noFlagBits))
				{
					ReplaceClientText(client, sBuffer, sBuffer2, sizeof(sBuffer2));
					String_RemoveExtraTags(sBuffer2, sizeof(sBuffer2));
					new Handle:hKv = CreateKeyValues("Stuff", "title", sBuffer2);
					KvSetColor(hKv, "color", value[0], value[1], value[2], value[3]);
					KvSetNum(hKv,   "level", 1);
					KvSetNum(hKv,   "time",  10);
					CreateDialog(client, hKv, DialogType_Msg);
					if (hKv != INVALID_HANDLE)
						CloseHandle(hKv);
				}
				strcopy(sBuffer, sizeof(sBuffer), sBuffer3);			
			}
		}
		Call_StartForward(g_hForwardPostAdvert);
		Call_PushString(sectionName);
		Call_PushString(sType);
		Call_PushString(sText);
		Call_PushCell(flagBits);
		Call_PushCell(noFlagBits);
		Call_Finish();
	}
	return Plugin_Continue;
}

stock IsPassedFwd(Action:returnVal)
{
	return ((returnVal == Plugin_Handled || returnVal == Plugin_Stop) ? false : true);
}

public Handler_DoNothing(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:Timer_CenterAd(Handle:timer, Handle:pack) 
{
	decl String:sText[256];
	static iCount = 0;
	
	ResetPack(pack);
	new iClient = GetClientOfUserId(ReadPackCell(pack));
	if (iClient == -1)
		return Plugin_Continue;
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
	if (args > 0)
	{
		decl String:arg[256];
		GetCmdArgString(arg, sizeof(arg));
		StripQuotes(arg);
		if (!ShowAdvert(arg))
		{
			ReplyToCommand(client, "%t %t", "Advert_Tag", "ShowAd_NotFound");
			return Plugin_Handled;
		}
	}
	else
		ShowAdvert();
	return Plugin_Handled;
}

public Action:Command_ReloadAds(client, args)
{
	if (g_bPluginEnabled)
	{
		#if defined ADVERT_SOURCE2009
		parseExtraChatColors();
		#endif
		if (g_hTopColorTrie != INVALID_HANDLE)
			ClearTrie(g_hTopColorTrie);
		initTopColorTrie();
		parseExtraTopColors();
		if (g_hAdvertisements != INVALID_HANDLE)
			CloseHandle(g_hAdvertisements);
		parseAdvertisements();
		ReplyToCommand(client, "%t %t", "Advert_Tag", "Config_Reloaded");
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
			new Handle:kv = CreateKeyValues("Advertisements");
			FileToKeyValues(kv, g_strConfigPath);
			KvGotoFirstSubKey(kv);
			decl String:sBuffer[5][256];
			do
			{
				KvGetSectionName(kv, sBuffer[4], sizeof(sBuffer[]));
				for (new i = 0; i < sizeof(g_strKeyValueKeyList); i++)
				{
					sBuffer[i][0] = '\0';
					KvGetString(kv, g_strKeyValueKeyList[i], sBuffer[i], sizeof(sBuffer[]), "");
				}

				AddAdvert(sBuffer[4], sBuffer[0], sBuffer[1], sBuffer[2], sBuffer[3], false, true);
			}
			while (KvGotoNextKey(kv));
			CloseHandle(kv);
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
	decl String:part[128], String:replace[128];
	for (new i = 0; i < 100; i++) 
	{
		if (FindCharInString(outputText, '{') != -1 || FindCharInString(outputText, '}') != -1)
		{
			if (MatchRegex(g_hDynamicTagRegex, outputText) > 0)
			{
				if (!GetRegexSubString(g_hDynamicTagRegex, 0, part, sizeof(part)))
				{
					continue;
				}
				strcopy(replace, sizeof(replace), part);
				if (StrContains(part, "{CONVAR_BOOL:", false) == 0)
				{
					replace[FindCharInString(replace, '}')] = '\0';
					new Handle:conVarFound = FindConVar(replace[13]);
					if (conVarFound != INVALID_HANDLE)
					{
						new conVarValue = GetConVarInt(conVarFound);
						if (conVarValue == 0 || conVarValue == 1)
							strcopy(replace, sizeof(replace), g_strConVarBoolText[conVarValue]);
						else
							replace[0] = '\0';
					}
					else
						replace[0] = '\0';
				}
				else if (StrContains(part, "{CONVAR:", false) == 0)
				{
					replace[FindCharInString(replace, '}')] = '\0';
					new Handle:conVarFound = FindConVar(replace[8]);
					if (conVarFound != INVALID_HANDLE)
						GetConVarString(conVarFound, replace, sizeof(replace));
					else
						replace[0] = '\0';
				}
				ReplaceString(outputText, outputText_maxLength, part, replace);
			}
			else
				break;
		}
		else
			break;
	}
	
	new i = 1;
	decl String:strTemp[256];
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetServerIP(strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetServerIP(strTemp, sizeof(strTemp), true);
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		Format(strTemp, sizeof(strTemp), "%i", Server_GetPort());
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetCurrentMap(strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		GetNextMap(strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		IntToString(g_iTickrate, strTemp, sizeof(strTemp));
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		FormatTime(strTemp, sizeof(strTemp), "%I:%M:%S%p");
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		FormatTime(strTemp, sizeof(strTemp), "%H:%M:%S");
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
	if (StrContains(outputText, g_tagRawText[i], false) != -1)
	{
		FormatTime(strTemp, sizeof(strTemp), "%x");
		ReplaceString(outputText, outputText_maxLength, g_tagRawText[i], strTemp, false);
	}
	i++;
	strTemp[0] = '\0';
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
	decl String:tag[128],
		 String:actual[128];
	new Function:func,
		Handle:plugin,
		Action:returnVal = Plugin_Continue,
		size = GetArraySize(g_hFuncArray),
		x = 0;
	while (x < size)
	{
		returnVal = Plugin_Continue;
		GetArrayString(g_hFuncArray, i, actual, sizeof(actual));
		if (StrContains(outputText, actual, false) == -1)
			continue;
		strcopy(tag, sizeof(tag), actual);
		x++;
		func = GetArrayCell(g_hFuncArray, x);
		x++;
		plugin = GetArrayCell(g_hFuncArray, x);
		x++;
		Call_StartFunction(plugin, func);
		Call_PushString(outputText);
		Call_PushStringEx(tag, sizeof(tag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushString(actual);
		Call_Finish(_:returnVal);
		if (returnVal == Plugin_Stop)
			break;
		if (returnVal != Plugin_Changed)
			continue;
		ReplaceString(outputText, outputText_maxLength, actual, tag, false);
	}
	x = 0;
	size = GetArraySize(g_hDynamicTagArray);
	new bool:stop = false,
		bool:con = false,
		flags = 0;
	while (x < size)
	{
		flags = 0;
		func = GetArrayCell(g_hDynamicTagArray, x);
		x++;
		plugin = GetArrayCell(g_hDynamicTagArray, x);
		x++;
		GetArrayString(g_hDynamicTagArray, i, actual, sizeof(actual));
		x++;
		flags = GetArrayCell(g_hDynamicTagArray, x);
		x++;
		stop = false;
		con = false;
		new Handle:regex = CompileRegex(actual, flags);
		for (new j = 0; j < 100; j++)
		{
			stop = false;
			con = false;
			returnVal = Plugin_Continue;
			if (FindCharInString(outputText, '{') == -1 || FindCharInString(outputText, '}') == -1)
				break;
			if (MatchRegex(regex, outputText) > 0)
			{
				if (!GetRegexSubString(regex, 0, tag, sizeof(tag)))
				{
					continue;
				}
				Call_StartFunction(plugin, func);
				Call_PushString(outputText);
				Call_PushStringEx(tag, sizeof(tag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushString(actual);
				Call_Finish(_:returnVal);
				if (returnVal == Plugin_Stop)
				{
					stop = true;
					break;
				}
				if (returnVal != Plugin_Changed)
				{
					con = true;
					continue;
				}
			}
			else
				break;
		}
		if (stop)
			break;
		if (con)
			continue;
		ReplaceString(outputText, outputText_maxLength, actual, tag, false);
	}
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
			GetClientName(client, strTemp, sizeof(strTemp));\
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		strTemp[0] = '\0';
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientAuthString(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		strTemp[0] = '\0';
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientIP(client, strTemp, sizeof(strTemp));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		strTemp[0] = '\0';
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			GetClientIP(client, strTemp, sizeof(strTemp), false);
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		strTemp[0] = '\0';
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			Format(strTemp, sizeof(strTemp), "%d", GetClientTime(client));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		i++;
		strTemp[0] = '\0';
		if (StrContains(outputText, g_clientRawText[i], false) != -1)
		{
			Format(strTemp, sizeof(strTemp), "%d", Client_GetMapTime(client));
			ReplaceString(outputText, outputText_maxLength, g_clientRawText[i], strTemp, false);
		}
		strTemp[0] = '\0';
		decl String:tag[128],
			 String:actual[128];
		new Function:func,
			Handle:plugin,
			Action:returnVal = Plugin_Continue,
			size = GetArraySize(g_hClientTagArray),
			x = 0;
		while (x < size)
		{
			returnVal = Plugin_Continue;
			GetArrayString(g_hClientTagArray, i, actual, sizeof(actual));
			if (StrContains(outputText, actual, false) == -1)
				continue;
			strcopy(tag, sizeof(tag), actual);
			x++;
			func = GetArrayCell(g_hClientTagArray, x);
			x++;
			plugin = GetArrayCell(g_hClientTagArray, x);
			x++;
			Call_StartFunction(plugin, func);
			Call_PushCell(client);
			Call_PushString(outputText);
			Call_PushStringEx(tag, sizeof(tag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
			Call_PushString(actual);
			Call_Finish(_:returnVal);
			if (returnVal == Plugin_Stop)
				break;
			if (returnVal != Plugin_Changed)
				continue;
			ReplaceString(outputText, outputText_maxLength, actual, tag, false);
		}
		x = 0;
		size = GetArraySize(g_hDynamicClientTagArray);
		new bool:stop = false,
			bool:con = false,
			flags = 0;
		while (x < size)
		{
			flags = 0;
			func = GetArrayCell(g_hDynamicClientTagArray, x);
			x++;
			plugin = GetArrayCell(g_hDynamicClientTagArray, x);
			x++;
			GetArrayString(g_hDynamicClientTagArray, i, actual, sizeof(actual));
			x++;
			flags = GetArrayCell(g_hDynamicClientTagArray, x);
			x++;
			stop = false;
			con = false;
			new Handle:regex = CompileRegex(actual, flags);
			for (new j = 0; j < 100; j++)
			{
				stop = false;
				con = false;
				returnVal = Plugin_Continue;
				if (FindCharInString(outputText, '{') == -1 || FindCharInString(outputText, '}') == -1)
					break;
				if (MatchRegex(regex, outputText) > 0)
				{
					if (!GetRegexSubString(regex, 0, tag, sizeof(tag)))
					{
						continue;
					}
					Call_StartFunction(plugin, func);
					Call_PushCell(client);
					Call_PushString(outputText);
					Call_PushStringEx(tag, sizeof(tag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
					Call_PushString(actual);
					Call_Finish(_:returnVal);
					if (returnVal == Plugin_Stop)
					{
						stop = true;
						break;
					}
					if (returnVal != Plugin_Changed)
					{
						con = true;
						continue;
					}
				}
				else
					break;
			}
			if (stop)
				break;
			if (con)
				continue;
			ReplaceString(outputText, outputText_maxLength, actual, tag, false);
		}
	}
	return;
}

stock SimpleRegexMatch_Ads(const String:str[], const String:pattern[], flags = 0, String:error[]="", maxLen = 0)
{
	new Handle:regex = CompileRegex(pattern, flags, error, maxLen);
	
	if (regex == INVALID_HANDLE)
	{
		return -1;	
	}
	
	new substrings = MatchRegex(regex, str);
	
	CloseHandle(regex);
	
	return substrings;	
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

public Native_CanViewAdvert(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new clientFlagBits = GetNativeCell(2);
	new noFlagBits = GetNativeCell(3);
	if (clientFlagBits == -1 && noFlagBits == -1)
		return true;
	if (g_bRootAccess && CheckCommandAccess(client, "extended_advert_root", ADMFLAG_ROOT))
		return true;
	if ((clientFlagBits == -1 || CheckCommandAccess(client, "extended_advert", clientFlagBits)) && (noFlagBits == -1 || !CheckCommandAccess(client, "extended_notview", noFlagBits)))
		return true;
	return false;
}

#if defined ADVERT_SOURCE2009
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
		#if defined ADVERT_SOURCE2009
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
	/*if (!ignoreChat)
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
	}*/
}

/** 
 * 
 * Modified version of SMLIB's Server_GetIPString
 * 
 */

stock Server_GetIPNumString(String:ipBuffer[], ipBuffer_maxLength, bool:useSteamTools)
{
	new ip;
	if (useSteamTools)
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
	else
	{
		new Handle:conVarHostIP = INVALID_HANDLE;
		if (conVarHostIP == INVALID_HANDLE)
			conVarHostIP = FindConVar("hostip");
		ip = GetConVarInt(conVarHostIP);
		LongToIP(ip, ipBuffer, ipBuffer_maxLength);	
	}
}

public OnPluginEnd()
{
	CloseHandle(g_hAdvertisements);
	CloseHandle(g_hTopColorTrie);
}