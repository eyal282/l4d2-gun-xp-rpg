#include <sourcemod>

#include <updater>

// Only one update URL can be active at once. Start with left4dhooks then PointSystemAPI.
#define UPDATE_URL "https://raw.githubusercontent.com/eyal282/l4d2-gun-xp-rpg/master/addons/sourcemod/updatefile.txt"
#define UPDATE_URL2 "https://raw.githubusercontent.com/eyal282/l4d2-point-system-api/master/addons/sourcemod/updatefile.txt"
#define UPDATE_URL3 "https://raw.githubusercontent.com/SilvDev/Left4DHooks/main/sourcemod/updater.txt"

#pragma semicolon 1
#pragma newdecls  required

public Plugin myinfo =
{
	name        = "Gun XP RPG Updater",
	author      = "Eyal282",
	description = "Enables auto updater support",
	version     = "1.0",
	url         = ""
};

Handle g_Timer;

public void OnMapEnd()
{
	RemoveServerTag2("GunXP");
	RemoveServerTag2("GunXP-RPG");
	RemoveServerTag2("GunXPRPG");
	RemoveServerTag2("RPG");
}

public void OnMapStart()
{
	AddServerTag2("GunXP");
	AddServerTag2("GunXP-RPG");
	AddServerTag2("GunXPRPG");
	AddServerTag2("RPG");

	g_Timer = INVALID_HANDLE;

}
public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	Func_OnAllPluginsLoaded();

	return Plugin_Continue;
}
			
public void Updater_OnPluginUpdated()
{
	if(!LibraryExists("GunXPMod") || !LibraryExists("left4dhooks") || !LibraryExists("PointSystemAPI"))
	{
		char MapName[64];
		GetCurrentMap(MapName, sizeof(MapName));

		ServerCommand("changelevel %s", MapName);
	}
}

public void Func_OnAllPluginsLoaded()
{
	if (LibraryExists("updater"))
	{
		if(!LibraryExists("left4dhooks"))
		{
			Updater_RemovePlugin();
			Updater_AddPlugin(UPDATE_URL3);
		}
		else if(!LibraryExists("PointSystemAPI"))
		{
			Updater_RemovePlugin();
			Updater_AddPlugin(UPDATE_URL2);
		}
		else if(!LibraryExists("GunXPMod"))
		{
			Updater_RemovePlugin();
			Updater_AddPlugin(UPDATE_URL);
		}
		else
		{
			return;
		}

		if(g_Timer != INVALID_HANDLE)
		{
			delete g_Timer;
		}

		g_Timer = CreateTimer(5.0, Timer_ForceUpdate, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ForceUpdate(Handle hTimer)
{

	Updater_ForceUpdate();

	g_Timer = INVALID_HANDLE;
	return Plugin_Stop;
}

/**
 * Adds an informational string to the server's public "tags".
 * This string should be a short, unique identifier.
 *
 *
 * @param tag            Tag string to append.
 * @noreturn
 */
stock void AddServerTag2(const char[] tag)
{
	Handle hTags = INVALID_HANDLE;
	hTags        = FindConVar("sv_tags");

	if (hTags != INVALID_HANDLE)
	{
		int flags = GetConVarFlags(hTags);

		SetConVarFlags(hTags, flags & ~FCVAR_NOTIFY);

		char tags[50];    // max size of sv_tags cvar
		GetConVarString(hTags, tags, sizeof(tags));
		if (StrContains(tags, tag, true) > 0) return;
		if (strlen(tags) == 0)
		{
			Format(tags, sizeof(tags), tag);
		}
		else
		{
			Format(tags, sizeof(tags), "%s,%s", tags, tag);
		}
		SetConVarString(hTags, tags, true);

		SetConVarFlags(hTags, flags);
	}
}

/**
 * Removes a tag previously added by the calling plugin.
 *
 * @param tag            Tag string to remove.
 * @noreturn
 */
stock void RemoveServerTag2(const char[] tag)
{
	Handle hTags = INVALID_HANDLE;
	hTags        = FindConVar("sv_tags");

	if (hTags != INVALID_HANDLE)
	{
		int flags = GetConVarFlags(hTags);

		SetConVarFlags(hTags, flags & ~FCVAR_NOTIFY);

		char tags[50];    // max size of sv_tags cvar
		GetConVarString(hTags, tags, sizeof(tags));
		if (StrEqual(tags, tag, true))
		{
			Format(tags, sizeof(tags), "");
			SetConVarString(hTags, tags, true);
			return;
		}

		int pos = StrContains(tags, tag, true);
		int len = strlen(tags);
		if (len > 0 && pos > -1)
		{
			bool found;
			char taglist[50][50];
			ExplodeString(tags, ",", taglist, sizeof(taglist[]), sizeof(taglist));
			for (int i = 0; i < sizeof(taglist[]); i++)
			{
				if (StrEqual(taglist[i], tag, true))
				{
					Format(taglist[i], sizeof(taglist), "");
					found = true;
					break;
				}
			}
			if (!found) return;
			ImplodeStrings(taglist, sizeof(taglist[]), ",", tags, sizeof(tags));
			if (pos == 0)
			{
				tags[0] = 0x20;
			}
			else if (pos == len - 1)
			{
				Format(tags[strlen(tags) - 1], sizeof(tags), "");
			}
			else
			{
				ReplaceString(tags, sizeof(tags), ",,", ",");
			}

			SetConVarString(hTags, tags, true);

			SetConVarFlags(hTags, flags);
		}
	}
}
