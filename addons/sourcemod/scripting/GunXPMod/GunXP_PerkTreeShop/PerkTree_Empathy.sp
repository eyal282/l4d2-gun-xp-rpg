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

// Make identifier as descriptive as possible.
native int GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null);
native int GunXP_RPGShop_IsPerkTreeUnlocked(int client, int perkIndex);

int empathyIndex = -1;

ConVar g_hKitDuration;

float g_fKitDuration;

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
    AddNormalSoundHook(SoundHook);
    RegisterPerkTree();

    g_hKitDuration = FindConVar("first_aid_kit_use_duration");

    g_fKitDuration = g_hKitDuration.FloatValue;

    for (int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;
            
        OnClientPutInServer(i);
    }
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if(StrEqual(sample, "player/survivor/heal/bandaging_1.wav"))
    {
        int reviver = entity;

        int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, empathyIndex);

        PrintToChatAll("%i", perkLevel);

        if(perkLevel == -1)
        {
            g_hKitDuration.FloatValue = g_fKitDuration;
        }
        else
        {
            g_hKitDuration.FloatValue = -(((g_fKitDuration * (100 * (perkLevel + 1)) / 100)) - g_fKitDuration);
        }

        return Plugin_Continue;
    }
}
public void OnClientPutInServer(int client)
{
    //SDKHook(client, SDKHook_UsePost, GetMaxHealth);
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, levelReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    levelReqs = new ArrayList(1);

    descriptions.PushString("+20%% medkit heal speed.");
    costs.Push(500);
    levelReqs.Push(4);

    descriptions.PushString("+40%% medkit heal speed.");
    costs.Push(2000);
    levelReqs.Push(9);

    descriptions.PushString("+60%% medkit heal speed.");
    costs.Push(8000);
    levelReqs.Push(15);

    descriptions.PushString("+80%% medkit heal speed.");
    costs.Push(15000);
    levelReqs.Push(21);

    descriptions.PushString("+100%% medkit heal speed.");
    costs.Push(75000);
    levelReqs.Push(26);

    empathyIndex = GunXP_RPGShop_RegisterPerkTree("Heal Speed", "Empathy", descriptions, costs, levelReqs);
}
