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
	name        = "Empathy Perk Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to reduce the duration of healing teammates.",
	version     = PLUGIN_VERSION,
	url         = ""
};

#define MIN_FLOAT -2147483647.0

int empathyIndex;

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

int g_iEmpathyCosts[] =
{
    100,
    200,
    400,
    700,
    1000,
    3000,
    5000,
    8000,
    20000,
    50000

};

int g_iEmpathyReqs[] =
{
    2000,
    5000,
    10000,
    20000,
    40000,
    50000,
    75000,
    100000,
    200000,
    300000
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

public void RPG_Perks_OnGetKitDuration(int reviver, int victim, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, empathyIndex);

    if(perkLevel == -1)
        return;

    float percent = g_fSpeedPercents[perkLevel];

    fDuration -= (percent * fDuration) / (percent + 100.0);
}


public void RPG_Perks_OnGetDefibDuration(int reviver, int victim, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, empathyIndex);

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

    for(int i=0;i < sizeof(g_iEmpathyCosts);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "+%.0f{PERCENT} Medkit & Defib Heal Speed", g_fSpeedPercents[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iEmpathyCosts[i]);
        xpReqs.Push(g_iEmpathyReqs[i]);
    }

    empathyIndex = GunXP_RPGShop_RegisterPerkTree("Heal Speed", "Empathy", descriptions, costs, xpReqs);
}
