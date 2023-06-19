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

public void RPG_Perks_OnGetIncapHealth(int reviver, bool bLedge, int &health)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, hardToKillIndex);

    if(perkLevel == -1)
        return;

    int percent = (25 * (perkLevel + 1));

    health += (percent * health) / (percent + 100);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("+25%% incap HP");
    costs.Push(100);
    xpReqs.Push(0);

    descriptions.PushString("+50%% incap HP.");
    costs.Push(300);
    xpReqs.Push(0);

    descriptions.PushString("+75%% incap HP.");
    costs.Push(700);
    xpReqs.Push(0);

    descriptions.PushString("+100%% incap HP.");
    costs.Push(1000);
    xpReqs.Push(0);

    descriptions.PushString("+125%% incap HP.");
    costs.Push(1500);
    xpReqs.Push(0);

    descriptions.PushString("+150%% incap HP.");
    costs.Push(2500);
    xpReqs.Push(0);

    descriptions.PushString("+175%% incap HP.");
    costs.Push(3500);
    xpReqs.Push(0);

    descriptions.PushString("+200%% incap HP.");
    costs.Push(5000);
    xpReqs.Push(0);

    hardToKillIndex = GunXP_RPGShop_RegisterPerkTree("Incap HP", "Hard to Kill", descriptions, costs, xpReqs);
}
