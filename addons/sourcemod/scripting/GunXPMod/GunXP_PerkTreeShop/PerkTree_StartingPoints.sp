#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

// Make identifier as descriptive as possible.
native int GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null);
native int GunXP_RPGShop_IsPerkTreeUnlocked(int client, int perkIndex);

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


public void PointSystemAPI_OnSetStartPoints(int client, L4DTeam team, float &fStartPoints, float fAveragePrice)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, startingPointsIndex);

    if(!IsFakeClient(client))
    {
        LogError("%i - %.2f", perkLevel, fAveragePrice);
    }
    if(perkLevel == -1)
    {
        return;
    }
    else
    {
	    fStartPoints += fAveragePrice * ((perkLevel + 1) * 0.05);
    }
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, levelReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    levelReqs = new ArrayList(1);

    descriptions.PushString("+15%% starting points (relative to average price of items)");
    costs.Push(300);
    levelReqs.Push(0);

    descriptions.PushString("+30%% starting points (relative to average price of items)");
    costs.Push(1000);
    levelReqs.Push(2);

    descriptions.PushString("+45%% starting points (relative to average price of items)");
    costs.Push(2000);
    levelReqs.Push(6);

    descriptions.PushString("+60%% starting points (relative to average price of items)");
    costs.Push(3500);
    levelReqs.Push(9);

    descriptions.PushString("+90%% starting points (relative to average price of items)");
    costs.Push(6000);
    levelReqs.Push(12);


    descriptions.PushString("+125%% starting points (relative to average price of items)");
    costs.Push(13000);
    levelReqs.Push(15);

    descriptions.PushString("+150%% starting points (relative to average price of items)");
    costs.Push(21000);
    levelReqs.Push(18);

    descriptions.PushString("+175%% starting points (relative to average price of items)");
    costs.Push(30000);
    levelReqs.Push(21);

    descriptions.PushString("+200%% starting points (relative to average price of items)");
    costs.Push(100000);
    levelReqs.Push(25);

    startingPointsIndex = GunXP_RPGShop_RegisterPerkTree("Starting Points", "Starting Points", descriptions, costs, levelReqs);
}
