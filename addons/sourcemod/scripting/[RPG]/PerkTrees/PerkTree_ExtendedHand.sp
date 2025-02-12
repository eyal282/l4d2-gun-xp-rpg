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
    name        = "Extended Hand Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to let you multi-revive survivors.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int g_iOverrideRevive = 0;

int extendedHandIndex = -1;

int g_iExtendedHandMaxRevive[] =
{
    1,
    1,
    2,
    3,
    4,
    5,
    6,
    7
};

float g_fExtendedHandRadius[] =
{
    64.0,
    128.0,
    180.0,
    250.0,
    320.0,
    400.0,
    512.0,
    65535.0
};

int g_iExtendedHandCosts[] =
{
    250,
    3000,
    25000,
    40000,
    60000,
    90000,
    250000,
    1000000
};

int g_iExtendedHandReqs[] =
{
    0,
    0,
    0,
    1000000,
    1250000,
    1750000,
    2250000,
    5000000
};

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


public void RPG_Perks_OnGetReviveHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(reviver, extendedHandIndex);

    if(perkLevel == -1)
        return;

    else if(RPG_Perks_IsEntityTimedAttribute(reviver, "Extended Hand Cooldown"))
        return;

    RPG_Perks_ApplyEntityTimedAttribute(reviver, "Extended Hand Cooldown", 0.1, COLLISION_SET, ATTRIBUTE_NEUTRAL);

    int revivesLeft = g_iExtendedHandMaxRevive[perkLevel];

    float fOrigin[3];
    GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fOrigin);

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!L4D_IsPlayerIncapacitated(i))
            continue;

        float fSurvivorOrigin[3];
        GetClientAbsOrigin(i, fSurvivorOrigin);

        if (GetVectorDistance(fOrigin, fSurvivorOrigin) < g_fExtendedHandRadius[perkLevel] && revivesLeft > 0)
        {
            revivesLeft--;

            ReviveWithOwnership(i, reviver);
        }
    }
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iExtendedHandCosts);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "When you / pet revive an incapped survivor, revives %i incapped survivors in a %.0f radius.", g_iExtendedHandMaxRevive[i], g_fExtendedHandRadius[i]);
        descriptions.PushString(TempFormat);
        costs.Push(g_iExtendedHandCosts[i]);
        xpReqs.Push(g_iExtendedHandReqs[i]);
    }

    extendedHandIndex = GunXP_RPGShop_RegisterPerkTree("Extended Hand", "Extended Hand", descriptions, costs, xpReqs);
}

stock void ReviveWithOwnership(int victim, int reviver)
{
    if(L4D_GetClientTeam(reviver) == L4DTeam_Infected)
    {
        int owner = GetEntPropEnt(reviver, Prop_Send, "m_hOwnerEntity");

        if(owner == -1)
            return;

        reviver = owner;
    }

    g_iOverrideRevive = reviver;

    SetEntPropEnt(victim, Prop_Send, "m_reviveOwner", -1);

    HookEvent("revive_success", Event_ReviveSuccessPre, EventHookMode_Pre);
    L4D_ReviveSurvivor(victim);
    UnhookEvent("revive_success", Event_ReviveSuccessPre, EventHookMode_Pre);

    g_iOverrideRevive = 0;

    SetEntPropEnt(victim, Prop_Send, "m_reviveOwner", -1);
}

public Action Event_ReviveSuccessPre(Event event, const char[] name, bool dontBroadcast)
{
    if(g_iOverrideRevive != 0)
    {
        SetEventInt(event, "userid", GetClientUserId(g_iOverrideRevive));

        g_iOverrideRevive = 0;

        return Plugin_Changed;
    }

    return Plugin_Continue;
}
