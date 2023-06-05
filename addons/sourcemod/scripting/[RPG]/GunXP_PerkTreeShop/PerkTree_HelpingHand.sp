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

public void GunXP_RPGShop_OnReloadRPGPlugins()
{
    RegisterPerkTree();
}

public void RPG_Perks_OnGetReviveDuration(int reviver, int victim, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, helpingHandIndex);

    if(perkLevel == -1)
        return;

    float percent = (40.0 * (float(perkLevel) + 1.0));

    fDuration -= (percent * fDuration) / (percent + 100.0);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("+40%% revive speed.");
    costs.Push(300);
    xpReqs.Push(1000);

    descriptions.PushString("+80%% revive speed.");
    costs.Push(1000);
    xpReqs.Push(2000);

    descriptions.PushString("+120%% revive speed.");
    costs.Push(5000);
    xpReqs.Push(10000);

    descriptions.PushString("+160%% revive speed.");
    costs.Push(10000);
    xpReqs.Push(25000);

    descriptions.PushString("+200%% revive speed.");
    costs.Push(50000);
    xpReqs.Push(200000);

    helpingHandIndex = GunXP_RPGShop_RegisterPerkTree("Revive Speed", "Helping Hand", descriptions, costs, xpReqs);
}
