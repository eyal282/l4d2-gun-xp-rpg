#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

// Make identifier as descriptive as possible.
native int GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null);
native int GunXP_RPGShop_IsPerkTreeUnlocked(int client, int perkIndex);

int helpingHandIndex = -1;

ConVar g_hReviveDuration;

float g_fReviveDuration;

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

    g_hReviveDuration = FindConVar("survivor_revive_duration");

    g_fReviveDuration = g_hReviveDuration.FloatValue;

    HookEvent("revive_begin", Event_ReviveBeginPre, EventHookMode_Pre);
}

public Action Event_ReviveBeginPre(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int reviver = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, helpingHandIndex);

    if(perkLevel == -1)
    {
        g_hReviveDuration.FloatValue = g_fReviveDuration;
    }
    else
    {
        g_hReviveDuration.FloatValue = -(((g_fReviveDuration * (20 * (perkLevel + 1)) / 100)) - g_fReviveDuration);
    }

    return Plugin_Continue;
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, levelReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    levelReqs = new ArrayList(1);

    descriptions.PushString("+20%% revive speed.");
    costs.Push(300);
    levelReqs.Push(4);

    descriptions.PushString("+40%% revive speed.");
    costs.Push(1000);
    levelReqs.Push(9);

    descriptions.PushString("+60%% revive speed.");
    costs.Push(5000);
    levelReqs.Push(15);

    descriptions.PushString("+80%% revive speed.");
    costs.Push(10000);
    levelReqs.Push(21);

    descriptions.PushString("+100%% revive speed.");
    costs.Push(50000);
    levelReqs.Push(26);

    helpingHandIndex = GunXP_RPGShop_RegisterPerkTree("Revive Speed", "Helping Hand", descriptions, costs, levelReqs);
}
