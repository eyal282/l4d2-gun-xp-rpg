#include <sourcemod>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude < updater>    // Comment out this line to remove updater support by force.
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

// Only one update URL can be active at once. Start with left4dhooks then PointSystemAPI.
#define UPDATE_URL "https://raw.githubusercontent.com/eyal282/l4d2-gun-xp-rpg/master/addons/sourcemod/updatefile.txt"
#define UPDATE_URL2 "https://raw.githubusercontent.com/SilvDev/Left4DHooks/main/sourcemod/updater.txt"

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
	if(!LibraryExists("GunXPMod") || !LibraryExists("left4dhooks"))
	{
		char MapName[64];
		GetCurrentMap(MapName, sizeof(MapName));

		ServerCommand("changelevel %s", MapName);
	}
}

public void OnAllPluginsLoaded()
{
	Func_OnAllPluginsLoaded();
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}
public void Func_OnAllPluginsLoaded()
{
	if (LibraryExists("updater"))
	{
		if(!LibraryExists("left4dhooks"))
		{
			Updater_AddPlugin(UPDATE_URL2);
		}
		else if(!LibraryExists("GunXPMod"))
		{
			Updater_AddPlugin(UPDATE_URL);
		}
		else
		{
			return;
		}

		CreateTimer(5.0, Timer_ForceUpdate);
	}
}

public Action Timer_ForceUpdate(Handle hTimer)
{
	Updater_ForceUpdate();

	return Plugin_Continue;
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