#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <GunXP-RPG>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

public Plugin myinfo =
{
	name        = "Starting Points Perk Tree --> Gun XP RPG",
	author      = "Eyal282",
	description = "Perk tree to give starting points in PSAPI",
	version     = PLUGIN_VERSION,
	url         = ""
};

int startingPointsIndex = -1;

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

public void PointSystemAPI_OnSetStartPoints(int client, L4DTeam team, float &fStartPoints, float fAveragePrice)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, startingPointsIndex);

    if(perkLevel == -1)
    {
        return;
    }
    else
    {
	    fStartPoints += fAveragePrice * ((perkLevel + 1) * 15.0/100.0);
    }
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("+15%% starting points (relative to average price of items)");
    costs.Push(100);
    xpReqs.Push(1000);

    descriptions.PushString("+30%% starting points (relative to average price of items)");
    costs.Push(200);
    xpReqs.Push(2500);

    descriptions.PushString("+45%% starting points (relative to average price of items)");
    costs.Push(300);
    xpReqs.Push(5000);

    descriptions.PushString("+60%% starting points (relative to average price of items)");
    costs.Push(400);
    xpReqs.Push(10000);

    descriptions.PushString("+75%% starting points (relative to average price of items)");
    costs.Push(500);
    xpReqs.Push(25000);

    descriptions.PushString("+90%% starting points (relative to average price of items)");
    costs.Push(600);
    xpReqs.Push(75000);

    descriptions.PushString("+105%% starting points (relative to average price of items)");
    costs.Push(700);
    xpReqs.Push(150000);

    descriptions.PushString("+120%% starting points (relative to average price of items)");
    costs.Push(800);
    xpReqs.Push(300000);

    descriptions.PushString("+135%% starting points (relative to average price of items)");
    costs.Push(900);
    xpReqs.Push(500000);

    descriptions.PushString("+150%% starting points (relative to average price of items)");
    costs.Push(1000);
    xpReqs.Push(1000000);

    startingPointsIndex = GunXP_RPGShop_RegisterPerkTree("Starting Points", "Starting Points", descriptions, costs, xpReqs);
}
