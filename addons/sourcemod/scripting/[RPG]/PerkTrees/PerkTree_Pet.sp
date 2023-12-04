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
    name        = "Marksman Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to LET'S FUCKING GOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

ConVar g_hDamagePriority;

int petIndex = -1;

int g_iLastButtons[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

/**
 * @brief Given the requested value, returns the required value to set considering all plugins wanting to set the m_flLaggedMovementValue value.
 * @remarks The last plugin requesting this value in the same frame will be the one writing the value.
 * @remarks Typically plugins set the m_flLaggedMovementValue in a PreThinkPost function.
 *
 * @notes Highly suggest viewing "Weapons Movement Speed" plugin by "Silvers" and adding the "Fix movement speed bug when jumping or staggering" code
 * @notes from that plugin to your plugins PreThinkPost function before setting the m_flLaggedMovementValue value. This fixes bugs with the m_flLaggedMovementValue
 * @Notes causing player to jump faster or slower when the value is changed from 1.0.
 *
 * @Notes View the "Weapons Movement Speed" plugin source to make this plugin optionally used if detected.
 * @Notes Example code usage: SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", L4D_LaggedMovement(client, 2.0));
 *
 * @param client    Client index of the person we're changing the speed value on
 * @param value     The speed we want to set on this player
 * @param forced    If forcing the value it will override all other plugins setting the value
 *
 * @return          The speed value we need to set
 */
native float L4D_LaggedMovement(int client, float value, bool forced = false);

float g_fPetDamages[] =
{
    400.0,
    1500.0,
    3500.0,
    7000.0,
    11000.0,
    17000.0,
    25000.0,
    45000.0,

};

float g_fPetReviveDurations[] =
{
    20.0,
    14.0,
    10.0,
    8.0,
    7.0,
    6.0,
    4.0,
    2.0
};

int g_iPetCosts[] =
{
    50000,
    100000,
    200000,
    400000,
    800000,
    1600000,
    3200000,
    6400000
};


int g_iPetReqs[] =
{
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
};

float g_fDamagePercentTank = 10.0;

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
    AutoExecConfig_SetFile("GunXP-PetPerkTree.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_pet_damage_priority", "-2", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();

    RegisterPerkTree();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public void OnMapStart()
{
    TriggerTimer(CreateTimer(5.0, Timer_MonitorPets, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public Action Timer_MonitorPets(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!IsPlayerAlive(i))
            continue;
        
        else if(GunXP_RPGShop_IsPerkTreeUnlocked(i, petIndex) == PERK_TREE_NOT_UNLOCKED)
            continue;

        if(RPG_FindClientPet(i) != 0)
            continue;

        FakeClientCommand(i, "sm_pet");
    }

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Infected)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        int owner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");

        if(owner == -1)
            continue;

        else if(RPG_Perks_GetZombieType(owner) != ZombieType_NotInfected)
            continue;

        SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", L4D_LaggedMovement(i, 1.75));
    }

    return Plugin_Continue;
}

public void GunXP_RPGShop_OnResetRPG(int client)
{
    if(GunXP_RPGShop_IsPerkTreeUnlocked(client, petIndex) == PERK_TREE_NOT_UNLOCKED)
        return;

    int pet = RPG_FindClientPet(client);

    if(pet != 0)
        ForcePlayerSuicide(pet);

}

public void RPG_Perks_OnZombiePlayerSpawned(int client)
{
    int owner = GetEntPropEnt(client, Prop_Send, "m_hOwnerEntity");

    if(!IsPlayer(owner))
        return;

    else if(RPG_Perks_GetZombieType(owner) != ZombieType_NotInfected)
        return;

    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", L4D_LaggedMovement(client, 1.75));
}
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    int lastButtons = g_iLastButtons[client];

    g_iLastButtons[client] = buttons;

    if(g_bSpam[client] || L4D_GetPinnedInfected(client) != 0 || L4D_GetAttackerCarry(client) != 0)
        return Plugin_Continue;

    if(buttons & IN_SPEED && !(lastButtons & IN_SPEED) && g_fNextExpireJump[client] > GetGameTime())
    {
    
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsPerkTreeUnlocked(client, petIndex) >= 0)
        {
            int pet = RPG_FindClientPet(client);
            
            if(pet == 0)
            {
                g_bSpam[client] = true;
            
                CreateTimer(0.3, Timer_SpamOff, client);
                
                FakeClientCommand(client, "sm_pet");
            }
            else
            {
                if(RPG_GetPlayerCarry(pet) != -1)
                {
                    PrintToChat(client, "Cannot teleport pet while it's carrying.");
                    PrintToChat(client, "Use !afk if you're stuck.");
                    return Plugin_Continue;
                }
                g_bSpam[client] = true;
            
                CreateTimer(5.0, Timer_SpamOff, client);

                float fOrigin[3];
                if (!UC_GetAimPositionBySize(client, pet, fOrigin))
                {
                    PrintToChat(client, "Cannot teleport");
                    return Plugin_Continue;
                }

                TeleportEntity(pet, fOrigin, NULL_VECTOR, NULL_VECTOR);
            }
        }

        return Plugin_Continue;
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(buttons & IN_SPEED)
        {
            g_iJumpCount[client]++;
        }
    }

    return Plugin_Continue;
}

public Action Timer_SpamOff(Handle Timer, int client)
{
    g_bSpam[client] = false;

    return Plugin_Continue;
}

public Action L4D2_Pets_OnCanPetReviveIncap(int victim, int pet, int owner, float &fDuration)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(owner, petIndex);

    if(perkLevel == PERK_TREE_NOT_UNLOCKED)
        return Plugin_Continue;

    fDuration = g_fPetReviveDurations[perkLevel];

    return Plugin_Continue;
}
public Action L4D2_Pets_OnCanHavePets(int client, L4D2ZombieClassType zclass, bool &bCanHave)
{
    if(zclass != L4D2ZombieClass_Charger)
    {
        bCanHave = false;
        return Plugin_Handled;
    }

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, petIndex);

    if(perkLevel >= 0 && !IsFakeClient(client))
        bCanHave = true;

    else
        bCanHave = false;

    ConVar cvar = FindConVar("l4d2_pets_dmg_scale");

    if(cvar != null)
    {
        int flags = cvar.Flags;

        cvar.Flags = (flags & ~FCVAR_NOTIFY);

        cvar.SetFloat(1.0, true);

        cvar.Flags = flags;
    }

    cvar = FindConVar("l4d2_pets_global_limit");

    if(cvar != null)
    {
        int flags = cvar.Flags;

        cvar.Flags = (flags & ~FCVAR_NOTIFY);

        cvar.SetInt(8, true);

        cvar.Flags = flags;
    }

    cvar = FindConVar("l4d2_pets_target_dist");

    if(cvar != null)
    {
        int flags = cvar.Flags;

        cvar.Flags = (flags & ~FCVAR_NOTIFY);

        cvar.SetFloat(131071.0, true);

        cvar.Flags = flags;
    }

    cvar = FindConVar("l4d2_pets_target_update_rate");

    if(cvar != null)
    {
        int flags = cvar.Flags;

        cvar.Flags = (flags & ~FCVAR_NOTIFY);

        cvar.SetFloat(1.0, true);

        cvar.Flags = flags;
    }

    return Plugin_Handled;
}
public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority != g_hDamagePriority.IntValue)
        return;

    else if(!IsPlayer(attacker))
        return;

    else if(L4D_GetClientTeam(attacker) != L4DTeam_Infected)
        return;

    int owner = GetEntPropEnt(attacker, Prop_Send, "m_hOwnerEntity");

    if(!IsPlayer(owner))
        return;

    else if(RPG_Perks_GetZombieType(owner) != ZombieType_NotInfected)
        return;

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(owner, petIndex);

    if(perkLevel == -1)
        perkLevel = 0;

    damage = g_fPetDamages[perkLevel];

    if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
    {
        damage = damage * (g_fDamagePercentTank / 100.0);
    }
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_fPetDamages);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "Pet deals %.0f damage, %.0f{PERCENT} to Tank, %.0f sec to revive incap", g_fPetDamages[i], g_fDamagePercentTank, g_fPetReviveDurations[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iPetCosts[i]);
        xpReqs.Push(g_iPetReqs[i]);
    }

    petIndex = GunXP_RPGShop_RegisterPerkTree("Charger Pet", "Charger Pet", descriptions, costs, xpReqs, _, _, "Triple press SHIFT to teleport charger to you");
}


stock int RPG_FindClientPet(int client, int startPos=0)
{
    for(int i=startPos+1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Infected)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        int owner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");

        if(owner == client)
            return i;
    }

    return 0;
}


// This function is perfect but I need to conduct tests to ensure no bugs occur.
stock bool UC_GetAimPositionBySize(int client, int target, float outputOrigin[3])
{
    float BrokenOrigin[3];
    float vecMin[3], vecMax[3], eyeOrigin[3], eyeAngles[3], Result[3], FakeOrigin[3], clientOrigin[3];

    GetClientMins(target, vecMin);
    GetClientMaxs(target, vecMax);

    GetEntPropVector(target, Prop_Data, "m_vecOrigin", BrokenOrigin);

    GetClientEyePosition(client, eyeOrigin);
    GetClientEyeAngles(client, eyeAngles);

    GetEntPropVector(client, Prop_Data, "m_vecOrigin", clientOrigin);

    TR_TraceRayFilter(eyeOrigin, eyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitPlayers);

    TR_GetEndPosition(FakeOrigin);

    Result = FakeOrigin;

    if (TR_PointOutsideWorld(Result))
        return false;

    float fwd[3];

    GetAngleVectors(eyeAngles, fwd, NULL_VECTOR, NULL_VECTOR);

    NegateVector(fwd);

    float clientHeight = eyeOrigin[2] - clientOrigin[2];
    float OffsetFix    = eyeOrigin[2] - Result[2];

    if (OffsetFix < 0.0)
        OffsetFix = 0.0;

    else if (OffsetFix > clientHeight + 1.3)
        OffsetFix = clientHeight + 1.3;

    ScaleVector(fwd, 1.3);

    int Timeout = 0;

    while (IsPlayerStuck(target, Result, (-1 * clientHeight) + OffsetFix))
    {
        AddVectors(Result, fwd, Result);

        Timeout++;

        if (Timeout > 8192)
            return false;
    }

    Result[2] += (-1 * clientHeight) + OffsetFix;

    outputOrigin = Result;

    return true;
}

stock bool IsPlayerStuck(int client, const float Origin[3] = NULL_VECTOR, float HeightOffset = 0.0)
{
    float vecMin[3], vecMax[3], vecOrigin[3];

    GetClientMins(client, vecMin);
    GetClientMaxs(client, vecMax);

    if (UC_IsNullVector(Origin))
    {
        GetClientAbsOrigin(client, vecOrigin);

        vecOrigin[2] += HeightOffset;
    }
    else
    {
        vecOrigin = Origin;

        vecOrigin[2] += HeightOffset;
    }

    TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);
    return TR_DidHit();
}

stock bool UC_IsNullVector(const float Vector[3])
{
    return (Vector[0] == NULL_VECTOR[0] && Vector[0] == NULL_VECTOR[1] && Vector[2] == NULL_VECTOR[2]);
}

public bool TraceRayDontHitPlayers(int entityhit, int mask)
{
    return (entityhit > MaxClients || entityhit == 0);
}
