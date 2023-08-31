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

int adrenalineRunIndex = -1;

int g_iAdrenalineTimes[] =
{
    5,
    8,
    12,
    15,
    20,
    25,
    30
};

int g_iAdrenalineCosts[] =
{
    200,
    400,
    600,
    800,
    1000,
    1200,
    1400
};


int g_iAdrenalineReqs[] =
{
    0,
    1000,
    2500,
    5000,
    7500,
    10000,
    30000,
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

public void OnPluginStart()
{
    RegisterPerkTree();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        int perkTree = GunXP_RPGShop_IsPerkTreeUnlocked(i, adrenalineRunIndex);

        if(perkTree == -1)
            continue;
            
        else if(GetEntProp(i, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(i) >= float(g_iAdrenalineTimes[perkTree]))
            continue;

        L4D2_UseAdrenaline(i, float(g_iAdrenalineTimes[perkTree]), false, false);
    }
}


public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iAdrenalineTimes);i++)
    {
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "%i seconds of adrenaline when a tank spawns.", g_iAdrenalineTimes[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iAdrenalineCosts[i]);
        xpReqs.Push(g_iAdrenalineReqs[i]);
    }

    adrenalineRunIndex = GunXP_RPGShop_RegisterPerkTree("Adrenaline on Tank Spawn", "Adrenaline Run", descriptions, costs, xpReqs);
}
