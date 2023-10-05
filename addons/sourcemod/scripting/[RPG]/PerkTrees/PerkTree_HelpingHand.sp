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
	name        = "Helping Hand Perk Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to reduce the duration of reviving teammates.",
	version     = PLUGIN_VERSION,
	url         = ""
};

#define MIN_FLOAT -2147483647.0

int helpingHandIndex = -1;

float g_fSpeedPercents[] =
{
    40.0,
    70.0,
    90.0,
    110.0,
    150.0,
    175.0,
    200.0,
    350.0,
    500.0,
    1000.0
};

int g_iHelpingHandCosts[] =
{
    30,
    80,
    200,
    700,
    1000,
    3000,
    5000,
    8000,
    20000,
    50000

};

int g_iHelpingHandReqs[] =
{
    0,
    0,
    0,
    40000,
    70000,
    100000,
    200000,
    400000,
    750000,
    2500000
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

public void RPG_Perks_OnGetReviveDuration(int reviver, int victim, bool bLedge, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, helpingHandIndex);

    if(perkLevel == -1)
        return;

    float percent = g_fSpeedPercents[perkLevel];

    fDuration -= (percent * fDuration) / (percent + 100.0);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iHelpingHandCosts);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "+%.0f{PERCENT} Revive Speed", g_fSpeedPercents[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iHelpingHandCosts[i]);
        xpReqs.Push(g_iHelpingHandReqs[i]);
    }

    helpingHandIndex = GunXP_RPGShop_RegisterPerkTree("Revive Speed", "Helping Hand", descriptions, costs, xpReqs);
}
