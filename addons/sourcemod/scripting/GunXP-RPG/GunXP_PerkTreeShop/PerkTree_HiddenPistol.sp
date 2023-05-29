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
	name        = "Hidden Pistol Perk Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to give pistols when incapped.",
	version     = PLUGIN_VERSION,
	url         = ""
};

#define MIN_FLOAT -2147483647.0

int hiddenPistolIndex = -1;

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

public void RPG_Perks_OnGetIncapWeapon(int reviver, int &index)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, hiddenPistolIndex);

    if(perkLevel == -1)
        return;

    index += perkLevel + 1;
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("Gain a pistol when incapacitated");
    costs.Push(750);
    xpReqs.Push(0);

    descriptions.PushString("Gain dual-pistols when incapacitated");
    costs.Push(2000);
    xpReqs.Push(0);

    descriptions.PushString("Gain Magnum Pistol when incapacitated");
    costs.Push(4500);
    xpReqs.Push(0);

    hiddenPistolIndex = GunXP_RPGShop_RegisterPerkTree("Hidden Pistol", "Hidden Pistol", descriptions, costs, xpReqs);
}
