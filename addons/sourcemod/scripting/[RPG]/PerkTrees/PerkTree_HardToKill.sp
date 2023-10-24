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
	name        = "Hard to Kill Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to increase incapped HP.",
	version     = PLUGIN_VERSION,
	url         = ""
};

#define MIN_FLOAT -2147483647.0

int hardToKillIndex = -1;

float g_fHealthIncrease[] =
{
    50.0,
    100.0,
    150.0,
    200.0,
    250.0,
    300.0,
    350.0,
    400.0
};

int g_iHardToKillCosts[] =
{
    3,
    30,
    300,
    3000,
    30000,
    300000,
    600000,
    1000000

};

int g_iHardToKillReqs[] =
{
    0,
    0,
    0,
    0,
    500000,
    1000000,
    1200000,
    1600000
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

public void RPG_Perks_OnGetIncapHealth(int client, bool bLedge, int &health)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, hardToKillIndex);

    if(perkLevel == -1)
        return;

    int percent = RoundFloat(g_fHealthIncrease[perkLevel]);

    health *= (RoundToFloor(1.0 + (float(percent) / 100.0)));
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iHardToKillCosts);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "+%.0f{PERCENT} Incap HP", g_fHealthIncrease[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iHardToKillCosts[i]);
        xpReqs.Push(g_iHardToKillReqs[i]);
    }

    hardToKillIndex = GunXP_RPGShop_RegisterPerkTree("Incap HP", "Hard to Kill", descriptions, costs, xpReqs);
}
