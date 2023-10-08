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
    name        = "Adrenaline Amplifier Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to make Adrenaline effects stronger",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

int adrenalineAmpIndex = -1;

float g_fAdrenalineDurationMultipliers[] =
{
    20.0,
    40.0,
    60.0,
    80.0,
    100.0
};

float g_fAdrenalineSpeedMultipliers[] =
{
    5.0,
    10.0,
    15.0,
    20.0,
    25.0
};

int g_iAdrenalineCosts[] =
{
    25000,
    50000,
    200000,
    500000,
    900000
};


int g_iAdrenalineReqs[] =
{
    700000,
    800000,
    900000,
    2000000,
    2700000
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

public void RPG_Perks_OnGetRPGSpeedModifiers(int priority, int client, int &overrideSpeedState, int &iLimpHealth, float &fRunSpeed, float &fWalkSpeed, float &fCrouchSpeed, float &fLimpSpeed, float &fCriticalSpeed, float &fWaterSpeed, float &fAdrenalineSpeed, float &fScopeSpeed, float &fCustomSpeed)
{
    if(priority != 0)
        return;

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, adrenalineAmpIndex);

    if(perkLevel == PERK_TREE_NOT_UNLOCKED)
        return;

    fAdrenalineSpeed += fAdrenalineSpeed * (g_fAdrenalineSpeedMultipliers[perkLevel] / 100.0);
}

public void RPG_Perks_OnGetAdrenalineDuration(int client, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, adrenalineAmpIndex);

    if(perkLevel == PERK_TREE_NOT_UNLOCKED)
        return;

    fDuration += fDuration * (g_fAdrenalineDurationMultipliers[perkLevel] / 100.0);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_fAdrenalineDurationMultipliers);i++)
    {
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "+%.0f{PERCENT} Adrenaline duration from all sources\n+%.0f{PERCENT} Adrenaline movement speed.", g_fAdrenalineDurationMultipliers[i], g_fAdrenalineSpeedMultipliers[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iAdrenalineCosts[i]);
        xpReqs.Push(g_iAdrenalineReqs[i]);
    }

    adrenalineAmpIndex = GunXP_RPGShop_RegisterPerkTree("Adrenaline Speed and Duration", "Adrenaline Amplifier", descriptions, costs, xpReqs);
}
