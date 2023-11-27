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

ConVar g_hRPGMultiplier;

float g_fReloadSpeedsIncrease[] =
{
    0.2,
    0.4,
    0.6,
    0.9,
    1.2,
    1.5
};

int g_iReloadCosts[] =
{
    500,
    1500,
    2500,
    5000,
    12500,
    75000
};

int g_iReloadReqs[] =
{
    1000,
    3000,
    5000,
    10000,
    25000,
    750000
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
    AutoExecConfig_SetFile("GunXP-SleightOfHandPerkTree.cfg");

    g_hRPGMultiplier = AutoExecConfig_CreateConVar("gun_xp_rpgshop_rpg_reload_multiplier", "2.0", "Sleight of hand reload multiplier for RPG");

    RegisterPerkTree();

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();
}


public void GunXP_OnReloadRPGPlugins()
{
   GunXP_ReloadPlugin();
}

public void WH_OnReloadModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, sleightOfHandIndex);

    if(perkLevel == -1)
        return;

    if(L4D2_GetWeaponId(weapon) == L4D2WeaponId_GrenadeLauncher)
    {
        speedmodifier += g_fReloadSpeedsIncrease[perkLevel] * g_hRPGMultiplier.FloatValue;
    }
    else
    {
        speedmodifier += g_fReloadSpeedsIncrease[perkLevel];
    }
}

public void WH_OnGetRateOfFire(int client, int weapon, int weapontype, float &speedmodifier)
{
     if(L4D2_GetWeaponId(weapon) == L4D2WeaponId_GrenadeLauncher)
    {
        speedmodifier = 10.0;
    }
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

        if(g_hRPGMultiplier.FloatValue == 1.0)
            FormatEx(TempFormat, sizeof(TempFormat), "+%i{PERCENT} reload speed", RoundFloat(g_fReloadSpeedsIncrease[i] * 100.0));

        else
            FormatEx(TempFormat, sizeof(TempFormat), "+%i{PERCENT} reload speed, but RPG has +%i{PERCENT} speed instead.", RoundFloat(g_fReloadSpeedsIncrease[i] * 100.0), RoundFloat(g_fReloadSpeedsIncrease[i] * 100.0 * g_hRPGMultiplier.FloatValue));

        descriptions.PushString(TempFormat);
        costs.Push(g_iReloadCosts[i]);
        xpReqs.Push(g_iReloadReqs[i]);
    }

    sleightOfHandIndex = GunXP_RPGShop_RegisterPerkTree("Reload Speed", "Sleight of Hand", descriptions, costs, xpReqs);
}
