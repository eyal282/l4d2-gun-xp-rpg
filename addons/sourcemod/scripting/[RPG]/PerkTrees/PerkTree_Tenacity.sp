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
	name        = "Tenacity Perk Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to increase your HP when you're revived.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tenacityIndex = -1;

int g_iTemporaryHealthPercents[] =
{
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
    100,
    100,
    100,
    100,
    100,
    100,
    100
};

int g_iPermanentHealthPercents[] =
{
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    10,
    20,
    30,
    40,
    50,
    60,
    70,
    80
};


int g_iTenacityCosts[] =
{
    0,
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800,
    900,
    1000,
    1100,
    1200,
    1300,
    1400,

};

int g_iTenacityReqs[] =
{
    0,
    500,
    1500,
    2500,
    5000,
    7500,
    10000,
    30000,
    40000,
    50000,
    60000,
    80000,
    100000,
    150000,
    200000,
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

public void RPG_Perks_OnGetReviveHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(victim, tenacityIndex);

    if(perkLevel == -1)
        perkLevel = 0;

    temporaryHealthPercent += g_iTemporaryHealthPercents[perkLevel];
    permanentHealthPercent += g_iPermanentHealthPercents[perkLevel];

}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iTemporaryHealthPercents);i++)
    {
        char TempFormat[128];

        if(g_iPermanentHealthPercents[i] > 0)
            FormatEx(TempFormat, sizeof(TempFormat), "+%i{PERCENT} temporary HP when revived, +%i{PERCENT} permanent HP when revived", g_iTemporaryHealthPercents[i], g_iPermanentHealthPercents[i]);

        else
            FormatEx(TempFormat, sizeof(TempFormat), "+%i{PERCENT} temporary HP when revived", g_iTemporaryHealthPercents[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iTenacityCosts[i]);
        xpReqs.Push(g_iTenacityReqs[i]);
    }

    tenacityIndex = GunXP_RPGShop_RegisterPerkTree("Revive Health", "Tenacity", descriptions, costs, xpReqs);
}
