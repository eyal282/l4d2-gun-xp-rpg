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
    name        = "Sleight of Hand Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree for faster reload speed.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

int sleightOfHandIndex = -1;

float g_fReloadSpeedsIncrease[] =
{
    0.2,
    0.4,
    0.6,
    0.9,
    1.2
};

int g_iReloadCosts[] =
{
    500,
    1500,
    2500,
    5000,
    12500
};

int g_iReloadReqs[] =
{
    1000,
    3000,
    5000,
    10000,
    25000
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


public void WH_OnReloadModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, sleightOfHandIndex);

    if(perkLevel == -1)
        return;

    speedmodifier += g_fReloadSpeedsIncrease[perkLevel];
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_fReloadSpeedsIncrease);i++)
    {
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "+%i{PERCENT} reload speed", RoundFloat(g_fReloadSpeedsIncrease[i] * 100.0));

        descriptions.PushString(TempFormat);
        costs.Push(g_iReloadCosts[i]);
        xpReqs.Push(g_iReloadReqs[i]);
    }

    sleightOfHandIndex = GunXP_RPGShop_RegisterPerkTree("Reload Speed", "Sleight of Hand", descriptions, costs, xpReqs);
}
