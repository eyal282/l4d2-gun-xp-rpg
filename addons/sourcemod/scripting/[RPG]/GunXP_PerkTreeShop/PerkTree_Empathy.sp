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

int empathyIndex = -1;

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

public void RPG_Perks_OnGetKitDuration(int reviver, int victim, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, empathyIndex);

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

    descriptions.PushString("+40%% medkit heal speed.");
    costs.Push(100);
    xpReqs.Push(2000);

    descriptions.PushString("+80%% medkit heal speed.");
    costs.Push(300);
    xpReqs.Push(5000);

    descriptions.PushString("+120%% medkit heal speed.");
    costs.Push(700);
    xpReqs.Push(20000);

    descriptions.PushString("+160%% medkit heal speed.");
    costs.Push(1000);
    xpReqs.Push(50000);

    descriptions.PushString("+200%% medkit heal speed.");
    costs.Push(3000);
    xpReqs.Push(400000);

    empathyIndex = GunXP_RPGShop_RegisterPerkTree("Heal Speed", "Empathy", descriptions, costs, xpReqs);
}
