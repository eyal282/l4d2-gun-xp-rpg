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

int combatMedicIndex = -1;

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

public void RPG_Perks_OnGetKitHealPercent(int reviver, int victim, int &percent)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, combatMedicIndex);

    if(perkLevel == -1)
        perkLevel = 0;

    percent += 50 + (10 * perkLevel);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("+50{PERCENT} HP for Medkit");
    costs.Push(0);
    xpReqs.Push(0);

    descriptions.PushString("+60{PERCENT} HP for Medkit");
    costs.Push(1000);
    xpReqs.Push(2000);

    descriptions.PushString("+70{PERCENT} HP for Medkit");
    costs.Push(5000);
    xpReqs.Push(10000);

    descriptions.PushString("+80{PERCENT} HP for Medkit");
    costs.Push(10000);
    xpReqs.Push(25000);

    descriptions.PushString("+90{PERCENT} HP for Medkit");
    costs.Push(20000);
    xpReqs.Push(100000);

    descriptions.PushString("Medkit fully restores HP");
    costs.Push(50000);
    xpReqs.Push(200000);

    combatMedicIndex = GunXP_RPGShop_RegisterPerkTree("Medkit Heal Percent", "Combat Medic", descriptions, costs, xpReqs);
}
