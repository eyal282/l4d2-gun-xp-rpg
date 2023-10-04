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
    6,
    9,
    12,
    15
};

int g_iCommonRequirements[] =
{
    10,
    8,
    6,
    4,
    2
};

int g_iTemporaryHealthReward[] =
{
    1,
    2,
    3,
    4,
    5
};

int g_iPermanentHealthReward[] =
{
    0,
    0,
    1,
    2,
    2
};


int g_iVampireCosts[] =
{
    0,
    1000,
    10000,
    25000,
    50000,

};

int g_iVampireReqs[] =
{
    1000,
    10000,
    50000,
    100000,
    250000,
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

        if(GetEntityHealth(attacker) + L4D_GetPlayerTempHealth(attacker) > GetEntityMaxHealth(attacker))
            break;
        
        GunXP_GiveClientHealth(attacker, g_iPermanentHealthReward[perkLevel], g_iTemporaryHealthReward[perkLevel]);
    }
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iTemporaryHealthReward);i++)
    {
        char TempFormat[128];

        if(g_iPermanentHealthReward[i] > 0)
            FormatEx(TempFormat, sizeof(TempFormat), "+%i Temp HP & +%i Perm HP per %i commons killed.\nSI are equal to %i commons.", g_iTemporaryHealthReward[i], g_iPermanentHealthReward[i], g_iCommonRequirements[i], g_iSIValues[i]);

        else
            FormatEx(TempFormat, sizeof(TempFormat), "+%i Temp HP per %i commons killed.\nSI are equal to %i commons.", g_iTemporaryHealthReward[i], g_iCommonRequirements[i], g_iSIValues[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iVampireCosts[i]);
        xpReqs.Push(g_iVampireReqs[i]);
    }

    vampireIndex = GunXP_RPGShop_RegisterPerkTree("Vampire", "Vampire", descriptions, costs, xpReqs);
}
