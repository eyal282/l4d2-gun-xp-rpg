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
    name        = "Endurance Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to increase your max HP per level",
    version     = PLUGIN_VERSION,
    url         = ""
};

int enduranceIndex = -1;

int g_iMaxHPIncreasePerLevel[] =
{
    1,
    2,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20
};


int g_iEnduranceCosts[] =
{
    0,
    10,
    20,
    30,
    40,
    50,
    599,
    699,
    799,
    899,
    999,
    1099,
    1199,
    1299,
    1399,
    1499,  
    1599,
    1699,
    1799,
    1899,
    1999,
};

int g_iEnduranceReqs[] =
{
    0,
    0,
    0,
    0,
    0,
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
    500000,
    1000000,
    2500000,
    5000000,
    7500000,
    10000000,
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

public void RPG_Perks_OnGetMaxHP(int priority, int client, int &maxHP)
{
    if(priority != 0)
        return;
    
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, enduranceIndex);

    if(perkLevel == -1)
        return;

    maxHP += g_iMaxHPIncreasePerLevel[perkLevel] * GunXP_RPG_GetClientLevel(client);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iMaxHPIncreasePerLevel);i++)
    {
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "+%i max HP per level", g_iMaxHPIncreasePerLevel[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iEnduranceCosts[i]);
        xpReqs.Push(g_iEnduranceReqs[i]);
    }

    enduranceIndex = GunXP_RPGShop_RegisterPerkTree("Max Health", "Endurance", descriptions, costs, xpReqs);
}
