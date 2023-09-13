
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
    name        = "Glutton Tank --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Glutton Tank that eats survivors.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int tankIndex;
int eatSurvivorIndex;

// [victim][attacker]
bool g_bEaten[MAXPLAYERS+1][MAXPLAYERS+1];
int g_iEatAttacker[MAXPLAYERS+1];

int g_iOldHealth[MAXPLAYERS+1];
int g_iOldMaxHealth[MAXPLAYERS+1];
bool g_bReleaseRandom[MAXPLAYERS+1];
bool g_bRoundLost;
float g_fLastOrigin[MAXPLAYERS+1][3];
int g_iCatchBot[MAXPLAYERS+1];

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "RPG_Tanks"))
    {
        RegisterTank();
    }
}

public void OnConfigsExecuted()
{
    RegisterTank();
}

public void OnPluginEnd()
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;        

        else if(g_iEatAttacker[i] <= 0)
            continue;

        int tank = g_iEatAttacker[i];

        if(!g_bEaten[i][tank])
            continue;

        SetEntProp(i, Prop_Send, "m_iTeamNum", 2);
        ChangeClientTeam(i, view_as<int>(L4DTeam_Survivor));
        L4D_State_Transition(i, STATE_ACTIVE);

        L4D_RespawnPlayer(i);

        SetEntityHealth(i, g_iOldHealth[i]);
    }
}

public void OnPluginStart()
{
    RegisterTank();

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_bot_replace", Event_BotReplacesAPlayer, EventHookMode_Post);
}

public Action Event_RoundStart(Handle hEvent, char[] Name, bool dontBroadcast)
{
    g_bRoundLost = false;

    return Plugin_Continue;
}


public Action Event_BotReplacesAPlayer(Handle event, const char[] name, bool dontBroadcast)
{
	int oldPlayer = GetClientOfUserId(GetEventInt(event, "player"));
	int newPlayer = GetClientOfUserId(GetEventInt(event, "bot"));

    g_iCatchBot[oldPlayer] = newPlayer;

    return Plugin_Continue;
}
public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
    if(RPG_Tanks_GetClientTank(client) != tankIndex)
        return;

    if(abilityIndex == eatSurvivorIndex)
        CastEatSurvivor(client);
}
public void CastEatSurvivor(int client)
{
    int survivor = FindRandomSurvivorWithoutIncap(client, 512.0);

    if(survivor == -1)
        return;
    
    g_bEaten[survivor][client] = true;
    g_iEatAttacker[survivor] = client;
    g_iOldHealth[survivor] = GetEntityHealth(survivor);
    g_iOldMaxHealth[survivor] = GetEntityMaxHealth(survivor);
    
    SetEntProp(survivor, Prop_Send, "m_iTeamNum", 3);
    ChangeClientTeam(survivor, view_as<int>(L4DTeam_Infected));
    L4D_State_Transition(survivor, STATE_OBSERVER_MODE);

    RPG_Perks_ApplyEntityTimedAttribute(survivor, "Eaten Alive", 1.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_REVERT);

    PrintToChatAll("%N was Eaten by the Tank! Shove the Tank to release him!", survivor);
}

public void L4D2_OnEntityShoved_Post(int client, int entity, int weapon, const float vecDir[3], bool bIsHighPounce)
{
    if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
        return;

    else if(RPG_Tanks_GetClientTank(entity) != tankIndex)
        return;

    else if(GetRandomInt(1, 100) > 10)
        return;

    else if(CountEatenSurvivors(entity) == 0)
        return;

    PrintToChatEyal("Tank was shoved");

    g_bReleaseRandom[entity] = true;

}

public Action L4D_OnTakeOverBot(int client)
{
    int tank = g_iEatAttacker[client];

    if(!g_bEaten[client][tank])
        return Plugin_Continue;

    g_bEaten[client][tank] = false;
    g_iEatAttacker[client] = 0;

    SetEntProp(client, Prop_Send, "m_iTeamNum", 2);
    ChangeClientTeam(client, view_as<int>(L4DTeam_Survivor));
    L4D_State_Transition(client, STATE_ACTIVE);

    L4D_RespawnPlayer(client);

    SetEntityHealth(client, g_iOldHealth[client]);

    g_iCatchBot[client] = 0;

    L4D_ReplaceWithBot(client);

    int bot = g_iCatchBot[client];
    if(bot != 0)
    {
        SetEntProp(bot, Prop_Send, "m_iTeamNum", 3);
        ChangeClientTeam(bot, view_as<int>(L4DTeam_Infected));
        L4D_State_Transition(bot, STATE_OBSERVER_MODE);
    }
    
    return Plugin_Handled;
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(!StrEqual(attributeName, "Eaten Alive"))
        return;

    else if(oldClient == newClient)
        return;

    int tank = g_iEatAttacker[oldClient];

 //   g_bEaten[newClient][tank] = true;
   // g_iEatAttacker[newClient] = tank;

    g_bEaten[oldClient][tank] = false;
    g_iEatAttacker[oldClient] = 0;

    //RPG_Perks_ApplyEntityTimedAttribute(newClient, "Eaten Alive", 1.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_REVERT);
    RPG_Perks_ApplyEntityTimedAttribute(oldClient, "Eaten Alive", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_REVERT);

    //SetEntProp(newClient, Prop_Send, "m_iTeamNum", 3);
    //ChangeClientTeam(newClient, view_as<int>(L4DTeam_Infected));
    //L4D_State_Transition(newClient, STATE_OBSERVER_MODE);
}

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(!StrEqual(attributeName, "Eaten Alive"))
        return;

    int tank = g_iEatAttacker[entity];

    // Takeover...
    if(tank <= 0 || !g_bEaten[entity][tank])
        return;

    int count = 0;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;        

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        count++;
    }
    
    if(count <= 1)
    {
        g_bRoundLost = true;
    }

    if(g_bRoundLost)
    {
        SetEntProp(entity, Prop_Send, "m_iTeamNum", 2);
        ChangeClientTeam(entity, view_as<int>(L4DTeam_Survivor));
        L4D_State_Transition(entity, STATE_ACTIVE);

        return;
    }
    if(g_bReleaseRandom[tank] || RPG_Perks_GetZombieType(tank) != ZombieType_Tank || RPG_Tanks_GetClientTank(tank) != tankIndex)
    {
        g_bReleaseRandom[tank] = false;

        int clients[MAXPLAYERS+1], num;

        for(int i=1;i <= MaxClients;i++)
        {
            if(!IsClientInGame(i))
                continue;        

            else if(!g_bEaten[i][tank])
                continue;

            clients[num++] = i;
        }

        int target = clients[GetRandomInt(0, num-1)];

        g_bEaten[target][tank] = false;
        SetEntProp(target, Prop_Send, "m_iTeamNum", 2);
        ChangeClientTeam(target, view_as<int>(L4DTeam_Survivor));
        L4D_State_Transition(target, STATE_ACTIVE);

        L4D_RespawnPlayer(target);

        SetEntityHealth(target, g_iOldHealth[target]);

        PrintToChatAll("%N was vomitted from the Tank!", target);

        RPG_Perks_ApplyEntityTimedAttribute(target, "Stun", 5.0, COLLISION_SET_IF_LOWER, ATTRIBUTE_NEGATIVE);    

        return;
    }
    else
    {
        GetEntPropVector(tank, Prop_Data, "m_vecAbsOrigin", g_fLastOrigin[tank]);
    }

    if(GetEntProp(entity, Prop_Send, "m_iTeamNum") != 3)
    {
        SetEntProp(entity, Prop_Send, "m_iTeamNum", 3);
        ChangeClientTeam(entity, view_as<int>(L4DTeam_Infected));
        L4D_State_Transition(entity, STATE_OBSERVER_MODE);
    }

    
    g_iOldHealth[entity] -= RoundToCeil(float(g_iOldMaxHealth[entity]) * 0.01);

    if(g_iOldHealth[entity] <= 0)
    {
        SetEntProp(entity, Prop_Send, "m_iTeamNum", 2);
        ChangeClientTeam(entity, view_as<int>(L4DTeam_Survivor));
        L4D_State_Transition(entity, STATE_ACTIVE);

        g_bEaten[entity][tank] = false;

        PrintToChatAll("%N was PROCESSED inside the Tank!!!", entity);

        return;
    }

    RPG_Perks_ApplyEntityTimedAttribute(entity, "Eaten Alive", 1.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_REVERT);
}
stock int FindRandomSurvivorWithoutIncap(int client, float fMaxDistance)
{
    float fOrigin[3];
    GetClientAbsOrigin(client, fOrigin);

    int   winner    = -1;
    float winnerDistance = fMaxDistance;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        // Technically unused because the tank can never be survivor but still...
        else if(client == i)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(L4D_IsPlayerIncapacitated(i))
            continue;

        float fSurvivorOrigin[3];
        GetClientAbsOrigin(i, fSurvivorOrigin);

        if (GetVectorDistance(fOrigin, fSurvivorOrigin) < winnerDistance)
        {
            winner    = i;
            winnerDistance = GetVectorDistance(fOrigin, fSurvivorOrigin);
        }
    }

    return winner;
}

public void RegisterTank()
{
    tankIndex = RPG_Tanks_RegisterTank(2, 0, "Glutton", "A tank that learned the size difference between survivors and Tanks.",
    5000000, 180, 0.2, 2000, 3000, true, true);

    eatSurvivorIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Eat Survivor", "Eats the closest standing survivor", 25, 25);

    RPG_Tanks_RegisterPassiveAbility(tankIndex, "Process Survivor", "Survivors being eaten take 1{PERCENT} damage each second, and become PROCESSED when incapped.");
    RPG_Tanks_RegisterPassiveAbility(tankIndex, "Weak Spot", "Shoving the tank has a 1{PERCENT} chance to force\nthe Tank to vomit the survivor.");
    RPG_Tanks_RegisterPassiveAbility(tankIndex, "Sticky Bile", "A vomited survivor is Stunned for 5 seconds");
}

stock int CountEatenSurvivors(int tank)
{
    int count = 0;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;        

        else if(!g_bEaten[i][tank])
            continue;

        count++;
    }

    return count;
}