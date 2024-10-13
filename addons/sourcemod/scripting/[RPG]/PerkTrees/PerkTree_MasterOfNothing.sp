#include <GunXP-RPG>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

public Plugin myinfo =
{
	name        = "Master Of Nothing Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to unlock every Perk Tree and Skill in Easy Difficulty.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int perkIndex = -1;

ConVar g_hDifficulty;

char g_sDifficulty[32];

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "GunXP_PerkTreeShop"))
    {
        RegisterPerkTree();
    }
}

public void OnConfigsExecuted()
{
    RegisterPerkTree();

}
public void OnPluginStart()
{
    RegisterPerkTree();

    g_hDifficulty = FindConVar("z_difficulty");

    HookConVarChange(g_hDifficulty, OnDifficultyChanged);
}

public void OnDifficultyChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    FormatEx(g_sDifficulty, sizeof(g_sDifficulty), newValue);
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void GunXP_OnGetPlayerIronman(int priority, int client, bool &bIronMan)
{
    if(priority != 1)
        return;

    else if(!StrEqual(g_sDifficulty, "Easy", false))
        return;

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, perkIndex, true);

    if(perkLevel == -1)
        return;

    bIronMan = true;
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("Skill active on Easy Difficulty.");
    costs.Push(400);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(30));

    perkIndex = GunXP_RPGShop_RegisterPerkTree("Ironman By Difficulty", "Master Of Nothing", descriptions, costs, xpReqs, _, _, "Applies Ironman state, which maxes all Perk Trees and Skills.");
}
