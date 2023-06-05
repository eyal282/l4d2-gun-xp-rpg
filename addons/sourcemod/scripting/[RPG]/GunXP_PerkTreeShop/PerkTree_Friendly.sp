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
	name        = "Friendly Perk Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to reduce friendly fire damage.",
	version     = PLUGIN_VERSION,
	url         = ""
};

#define MIN_FLOAT -2147483647.0

int friendlyIndex = -1;

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

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill)
{
    if(priority != 0)
        return;

    else if(!IsPlayer(victim) || !IsPlayer(attacker))
        return;

    else if(L4D_GetClientTeam(victim) != L4D_GetClientTeam(attacker))
        return;

    int perkLevel1 = GunXP_RPGShop_IsPerkTreeUnlocked(victim, friendlyIndex);
    int perkLevel2 = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, friendlyIndex);

    int perkLevel = perkLevel1;

    if(perkLevel2 > perkLevel)
        perkLevel = perkLevel2;

    float percent = (20.0 * (float(perkLevel) + 1.0));

    damage -= damage * (percent / 100.0);

    return;
}
public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("-20%% friendly fire damage taken and received.\nDoesn't stack.");
    costs.Push(100);
    xpReqs.Push(0);

    descriptions.PushString("-40%% friendly fire damage taken and received.\nDoesn't stack.");
    costs.Push(300);
    xpReqs.Push(0);

    descriptions.PushString("-60%% friendly fire damage taken and received.\nDoesn't stack.");
    costs.Push(700);
    xpReqs.Push(0);

    descriptions.PushString("-80%% friendly fire damage taken and received.\nDoesn't stack.");
    costs.Push(1000);
    xpReqs.Push(0);

    descriptions.PushString("No friendly fire damage taken and received.");
    costs.Push(1500);
    xpReqs.Push(0);

    friendlyIndex = GunXP_RPGShop_RegisterPerkTree("Friendly Fire Decrease", "Friendly", descriptions, costs, xpReqs);
}
