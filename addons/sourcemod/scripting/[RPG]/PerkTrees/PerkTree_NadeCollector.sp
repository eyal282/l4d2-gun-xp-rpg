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
    name        = "Nade Collector Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to give a random grenade when killing X common infected.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MAX_INT 2147483647

int nadeCollectorIndex = -1;

int g_iCommonKillsLeft[MAXPLAYERS+1] = {MAX_INT, ...};

int g_iCollectorGoals[] =
{
    400,
    300,
    250,
    200,
    150,
    100,
    80,
    70,
    60,
    50,
    40,
    30
};

int g_iCollectorCosts[] =
{
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
};


int g_iCollectorReqs[] =
{
    5000,
    10000,
    15000,
    20000,
    25000,
    30000,
    50000,
    200000,
    500000,
    1000000,
    3000000,
    5000000
};


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

public void OnMapStart()
{
    for(int i=0;i < sizeof(g_iCommonKillsLeft);i++)
    {
        g_iCommonKillsLeft[i] = MAX_INT;
    }
}

public void OnClientConnected(int client)
{
    g_iCommonKillsLeft[client] = MAX_INT;
}

public void OnPluginStart()
{
    RegisterPerkTree();

    HookEvent("player_death", Event_PlayerOrCommonDeath, EventHookMode_Post);
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public Action Event_PlayerOrCommonDeath(Handle hEvent, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

    //int victimEntity = GetEventInt(hEvent, "entityid");

    if(attacker == 0)
        return Plugin_Continue;

    else if(L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return Plugin_Continue;

    char sVictimName[16];
    GetEventString(hEvent, "victimname", sVictimName, sizeof(sVictimName));

    if(!StrEqual(sVictimName, "Infected", false))
        return Plugin_Continue;

    char weaponName[64];
    GetEventString(hEvent, "weapon", weaponName, sizeof(weaponName));

    int type = GetEventInt(hEvent, "type");

    // Ultimate Samurai
    if(!StrEqual(weaponName, "melee"))
    {
        if(type & DMG_BURN || type & DMG_BLAST)
            return Plugin_Continue;
    }

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, nadeCollectorIndex);

    if(perkLevel == PERK_TREE_NOT_UNLOCKED)
        return Plugin_Continue;

    if(g_iCommonKillsLeft[attacker] > g_iCollectorGoals[perkLevel])
    {
        g_iCommonKillsLeft[attacker] = g_iCollectorGoals[perkLevel];
    }

    g_iCommonKillsLeft[attacker]--;

    if(g_iCommonKillsLeft[attacker] <= 0)
    {
        if(GetPlayerWeaponSlot(attacker, L4D_WEAPON_SLOT_GRENADE) != -1)
        {
            PrintToChat(attacker, "\x04[Gun-XP] \x01You will get a nade after throwing your current one.");

            return Plugin_Continue;
        }
        
        switch(GetRandomInt(0, 2))
        {
            case 0: GivePlayerItem(attacker, "weapon_vomitjar");
            case 1: GivePlayerItem(attacker, "weapon_molotov");
            case 2: GivePlayerItem(attacker, "weapon_pipebomb");
        }

        g_iCommonKillsLeft[attacker] = MAX_INT;
    }

    return Plugin_Continue;
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iCollectorGoals);i++)
    {
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "Random grenade every %i CI kills. Nades do not increase this", g_iCollectorGoals[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iCollectorCosts[i]);
        xpReqs.Push(g_iCollectorReqs[i]);
    }

    nadeCollectorIndex = GunXP_RPGShop_RegisterPerkTree("Nade every X Kills", "Nade Collector", descriptions, costs, xpReqs);
}

public void GunXP_RPGShop_OnResetRPG(int client)
{
    if(GunXP_RPGShop_IsPerkTreeUnlocked(client, nadeCollectorIndex) > PERK_TREE_NOT_UNLOCKED)
    {
        g_iCommonKillsLeft[client] = MAX_INT;
    }
}