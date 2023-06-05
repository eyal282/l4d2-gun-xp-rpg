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
    name        = "Vampire Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to give temporary health when killing commons and SI.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

int vampireIndex = -1;

int g_iCommonKills[MAXPLAYERS+1];

int g_iSIValues[] =
{
    3,
    4,
    5,
    5,
    5
};

int g_iCommonRequirements[] =
{
    5,
    4,
    3,
    3,
    4
};

int g_iTemporaryHealthReward[] =
{
    1,
    1,
    1,
    0,
    0
};

int g_iPermanentHealthReward[] =
{
    0,
    0,
    0,
    1,
    2
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
    for(int i=0;i < sizeof(g_iCommonKills);i++)
    {
        g_iCommonKills[i] = 0;
    }
}
public void OnPluginStart()
{
    RegisterPerkTree();

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("infected_death", Event_CommonDeath, EventHookMode_Post);
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    
    if(victim == 0)
        return Plugin_Continue;

    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
    
    if(attacker == victim || attacker == 0)
        return Plugin_Continue;

    else if(GetClientTeam(attacker) == GetClientTeam(victim))        
        return Plugin_Continue;

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, vampireIndex);

    if(perkLevel == -1)
        return Plugin_Continue;

    g_iCommonKills[attacker] += g_iSIValues[perkLevel];

    CalculateVampireGain(attacker);

    return Plugin_Continue;
}


public Action Event_CommonDeath(Handle hEvent, const char[] name, bool dontBroadcast)
{

    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

    if(attacker != 0 && L4D_GetClientTeam(attacker) == L4DTeam_Survivor)
    {
        int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, vampireIndex);

        if(perkLevel == -1)
            return Plugin_Continue;

        g_iCommonKills[attacker]++;

        CalculateVampireGain(attacker);
    }

    return Plugin_Continue;
}

stock void CalculateVampireGain(int attacker)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, vampireIndex);

    while(g_iCommonKills[attacker] >= g_iCommonRequirements[perkLevel])
    {
        g_iCommonKills[attacker] -= g_iCommonRequirements[perkLevel];

        int hpToAdd = g_iPermanentHealthReward[perkLevel];

        if(GetEntityHealth(attacker) + L4D_GetPlayerTempHealth(attacker) > GetEntityMaxHealth(attacker))
            break;

        hpToAdd = g_iTemporaryHealthReward[perkLevel];
        
        GunXP_GiveClientHealth(attacker, g_iPermanentHealthReward[perkLevel], g_iTemporaryHealthReward[perkLevel]);
    }
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("+1 temporary health per 5 commons killed.\nSI are equal to 3 commons.");
    costs.Push(1000);
    xpReqs.Push(0);

    descriptions.PushString("+1 temporary health per 4 commons killed.\nSI are equal to 4 commons.");
    costs.Push(4000);
    xpReqs.Push(6000);

    descriptions.PushString("+1 temporary health per 3 commons killed.\nSI are equal to 5 commons.");
    costs.Push(10000);
    xpReqs.Push(12500);

    descriptions.PushString("+1 permanent health per 3 commons killed.\nSI are equal to 5 commons.");
    costs.Push(10000);
    xpReqs.Push(12500);

    descriptions.PushString("+2 permanent health per 4 commons killed.\nSI are equal to 5 commons.");
    costs.Push(50000);
    xpReqs.Push(100000);

    vampireIndex = GunXP_RPGShop_RegisterPerkTree("Vampire", "Vampire", descriptions, costs, xpReqs);
}
