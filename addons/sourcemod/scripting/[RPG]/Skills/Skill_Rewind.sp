
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
    name        = "Rewind Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Endgame Skill that lets you rewind yourself into the past.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int rewindIndex;

ArrayList g_aHistory;
ArrayList g_aWeaponHistory;

int g_iJumpCount[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];
int g_iLastImpulse[MAXPLAYERS+1];

// -1 for do nothing, 0 for active search
int g_iCheckEntity = -1;

enum struct enHistory
{
    float fSecondsAgo;
    int userId;
    int reviveCount;
    bool bAlive;
    bool bIncap;
    bool bHanging;
    bool bThirdStrike;
    float fOrigin[3];
    float fAngles[3];
    float fVelocity[3];

    float fHangAirPos[3];
    float fHangPos[3];
    float fHangStandPos[3];
    float fHangNormal[3];

    // While I don't recover pins, we need pinState to determine which get-up we'll use.
    L4D2ZombieClassType pinClass;
}

enum struct enWeapon
{
    float fSecondsAgo;
    int userId;
    char sClassname[64];
    int clipAmmo;
    int reserveAmmo;
    int upgradedAmmo;
    int upgradeBits;
    bool bActive;
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "GunXP_SkillShop"))
    {
        RegisterSkill();
    }
}

public void OnConfigsExecuted()
{
    RegisterSkill();

}

// Must be able to add up to 1.0, so either 0.2, 0.5 or 1.0
#define REWIND_MONITOR_INTERVAL 0.2

// Whole number
#define MAX_REWIND_TIME 30.0

public void OnMapStart()
{
    CreateTimer(REWIND_MONITOR_INTERVAL, Timer_MonitorRewind, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Timer_MonitorRewind(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(IsFakeClient(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!GunXP_RPGShop_IsSkillUnlocked(i, rewindIndex))
            continue;

        enHistory history;

        history.fSecondsAgo = 0.0; // Immediately gets pushed back afterwards.
        history.userId = GetClientUserId(i);

        // Not sure if I care now, but this ignores temporary health.
        if(!IsPlayerAlive(i) || (L4D_EstimateFallingDamage(i) >= RPG_Perks_GetClientHealth(i) && !L4D_IsPlayerHangingFromLedge(i)))
        {
            history.bAlive = false;

            g_aHistory.PushArray(history);
        }
        else
        {
            history.bAlive = true;
            history.bIncap = L4D_IsPlayerIncapacitated(i);
            history.bHanging = L4D_IsPlayerHangingFromLedge(i);
            history.reviveCount = GetEntProp(i, Prop_Send, "m_currentReviveCount");
            history.bThirdStrike = view_as<bool>(GetEntProp(i, Prop_Send, "m_bIsOnThirdStrike"));

            GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", history.fOrigin);   
            GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", history.fVelocity);
            GetClientEyeAngles(i, history.fAngles);
            
            if(history.bHanging)
            {
                GetEntPropVector(i, Prop_Send, "m_hangAirPos", history.fHangAirPos);
                GetEntPropVector(i, Prop_Send, "m_hangPos", history.fHangPos);
                GetEntPropVector(i, Prop_Send, "m_hangStandPos", history.fHangStandPos);
                GetEntPropVector(i, Prop_Send, "m_hangNormal", history.fHangNormal);
            }

            int pinner = L4D2_GetInfectedAttacker(i);
            
            if(pinner != -1)
            {
                history.pinClass = L4D2_GetPlayerZombieClass(pinner);
            }
            else
            {
                history.pinClass = L4D2ZombieClass_NotInfected;
            }

            g_aHistory.PushArray(history);

            for (int slot = 0; slot <= 4; slot++)
            {
                int entity = GetPlayerWeaponSlot(i, slot);
                
                if (entity != -1)
                {
                    enWeapon weapon;
                    weapon.userId = GetClientUserId(i);
                    weapon.fSecondsAgo = 0.0; // Immediately gets pushed back afterwards.

                    GetEdictClassname(entity, weapon.sClassname, sizeof(enWeapon::sClassname));

                    if(HasEntProp(entity, Prop_Data, "m_strMapSetScriptName"))
                    {
                        GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", weapon.sClassname, sizeof(enWeapon::sClassname));
                    }

                    weapon.reserveAmmo = L4D_GetReserveAmmo(i, entity);
                    weapon.clipAmmo = GetEntProp(entity, Prop_Send, "m_iClip1");
                    weapon.upgradeBits = L4D2_GetWeaponUpgrades(entity);
                    weapon.upgradedAmmo = L4D2_GetWeaponUpgradeAmmoCount(entity);
                    weapon.bActive = (entity == GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon"));

                    g_aWeaponHistory.PushArray(weapon);
                }
            }
        }
    }


    // Cannot declare a size as it can change when we remove an Array's cell.
    for(int i=0;i < g_aHistory.Length;i++)
    {
        enHistory history;
        g_aHistory.GetArray(i, history);

        history.fSecondsAgo += REWIND_MONITOR_INTERVAL;

        if(history.fSecondsAgo - MAX_REWIND_TIME >= 0.001)
        {
            g_aHistory.Erase(i);
            i--;
        }
        else
            g_aHistory.SetArray(i, history);
    }

    
    // Cannot declare a size as it can change when we remove an Array's cell.
    for(int i=0;i < g_aWeaponHistory.Length;i++)
    {
        enWeapon weapon;
        g_aWeaponHistory.GetArray(i, weapon);

        weapon.fSecondsAgo += REWIND_MONITOR_INTERVAL;

        if(weapon.fSecondsAgo - MAX_REWIND_TIME >= 0.001)
        {
            g_aWeaponHistory.Erase(i);
            i--;
        }
        else
        {
            g_aWeaponHistory.SetArray(i, weapon);
        }
    }

    return Plugin_Continue;
}

public void OnPluginStart()
{
    g_aHistory = new ArrayList(sizeof(enHistory));
    g_aWeaponHistory = new ArrayList(sizeof(enWeapon));

    RegConsoleCmd("sm_rewind", Command_Rewind, "sm_rewind <sec> - Rewind yourself that many seconds into the past.");

    RegisterSkill();
}


public void OnEntityCreated(int entity, const char[] classname)
{
    // Left4Dhooks may decide to create a logic_script if no other one exists.
    if (StrEqual(classname, "logic_script"))
        return;

    else if (g_iCheckEntity == 0)
        g_iCheckEntity = entity;
}

public Action Command_Rewind(int client, int args)
{
    if(args == 0)
    {
        ReplyToCommand(client, "Usage: sm_rewind <sec>");
        return Plugin_Handled;
    }
    else if(!IsPlayerAlive(client))
    {
        ReplyToCommand(client, "You must be alive to use this command!");
        return Plugin_Handled;
    }
    else if(!GunXP_RPGShop_IsSkillUnlocked(client, rewindIndex))
    {
        ReplyToCommand(client, "You must unlock this skill to use this command!");
        return Plugin_Handled;
    }

    char sArg[16];
    GetCmdArg(1, sArg, sizeof(sArg));
    int seconds = StringToInt(sArg);

    return RewindTime(client, seconds);
}

stock Action RewindTime(int client, int seconds)
{
    float fSeconds = float(seconds);

    if(seconds <= 0)
    {
        ReplyToCommand(client, "Invalid rewind time!");
        return Plugin_Handled;
    }
    else if(seconds > MAX_REWIND_TIME)
    {
        ReplyToCommand(client, "Max rewind time is %.0f seconds!", MAX_REWIND_TIME);
        return Plugin_Handled;
    }
    
    int timesUsed, maxUses;

    RPG_Perks_GetClientLimitedAbility(client, "Rewind Yourself", timesUsed, maxUses);

    if(timesUsed >= maxUses)
    {
        ReplyToCommand(client, "Rewind Ability is fully used up (%i/%i)!", timesUsed, maxUses);

        return Plugin_Handled;
    }

    bool bFail = true;

    for(int i=0;i < g_aHistory.Length;i++)
    {
        enHistory history;
        g_aHistory.GetArray(i, history);

        if(FloatAbs(history.fSecondsAgo - fSeconds) > 0.001)
            continue;

        if(!history.bAlive)
            continue;

        else if(history.userId != GetClientUserId(client))
            continue;

        bFail = false;

        bool success = RPG_Perks_UseClientLimitedAbility(client, "Rewind Yourself");

        if(!success)
        {
            return Plugin_Handled;
        }


        RPG_Perks_GetClientLimitedAbility(client, "Rewind Yourself", timesUsed, maxUses);

        PrintToChat(client, "Rewound %i sec into the past (%i/%i)", seconds, timesUsed, maxUses);

        int pinner = L4D2_GetInfectedAttacker(client);

        if(pinner != -1)
        {
            L4D_StaggerPlayer(pinner, pinner, {0.0, 0.0, 0.0});

            // This unstaggers.
            char TempFormat[128];
            FormatEx(TempFormat, sizeof(TempFormat), "GetPlayerFromUserID(%i).SetModel(GetPlayerFromUserID(%i).GetModelName())", GetClientUserId(pinner), GetClientUserId(pinner));
            L4D2_ExecVScriptCode(TempFormat);
        }

        // This unstaggers.
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "GetPlayerFromUserID(%i).SetModel(GetPlayerFromUserID(%i).GetModelName())", GetClientUserId(client), GetClientUserId(client));
        L4D2_ExecVScriptCode(TempFormat);

        TeleportEntity(client, history.fOrigin, history.fAngles, history.fVelocity);


        if(history.bHanging && L4D_IsPlayerHangingFromLedge(client))
        {
            SetEntPropVector(client, Prop_Send, "m_hangAirPos", history.fHangAirPos);
            SetEntPropVector(client, Prop_Send, "m_hangPos", history.fHangPos);
            SetEntPropVector(client, Prop_Send, "m_hangStandPos", history.fHangStandPos);
            SetEntPropVector(client, Prop_Send, "m_hangNormal", history.fHangNormal);
        }
        else if((history.bIncap && !L4D_IsPlayerIncapacitated(client)))
        {
            SetEntityHealth(client, 99);
            RPG_Perks_SetClientTempHealth(client, 0);
            L4D_SetPlayerIncappedDamage(client);

            if(history.bHanging)
            {
                SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1);
                SetEntityMoveType(client, MOVETYPE_NONE);
                SetEntPropVector(client, Prop_Send, "m_hangAirPos", history.fHangAirPos);
                SetEntPropVector(client, Prop_Send, "m_hangPos", history.fHangPos);
                SetEntPropVector(client, Prop_Send, "m_hangStandPos", history.fHangStandPos);
                SetEntPropVector(client, Prop_Send, "m_hangNormal", history.fHangNormal);
            }

        }
        else if(!history.bIncap && L4D_IsPlayerIncapacitated(client))
        {
            L4D_ReviveSurvivor(client);
        }


        SetEntProp(client, Prop_Send, "m_currentReviveCount", history.reviveCount);
        SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", history.bThirdStrike);

        break;

    }

    if(bFail)
    {
        ReplyToCommand(client, "You sense death if you rewind there...");
        return Plugin_Handled;
    }
    
    for (int slot = 0; slot <= 4; slot++)
    {
        int entity = GetPlayerWeaponSlot(client, slot);
        
        if (entity != -1)
        {
            AcceptEntityInput(entity, "Kill");
        }
    }

    // Cannot declare a size as it can change when we remove an Array's cell.

    int activeWeapon = -1;

    for(int i=0;i < g_aWeaponHistory.Length;i++)
    {
        enWeapon weapon;
        g_aWeaponHistory.GetArray(i, weapon);

        if(FloatAbs(weapon.fSecondsAgo - fSeconds) > 0.001)
            continue;

        else if(weapon.userId != GetClientUserId(client))
            continue;

        char sClassname[64];
        FormatEx(sClassname, sizeof(sClassname), weapon.sClassname);

        // CreateMeleeWeapon can freely create guns.
        ReplaceStringEx(sClassname, sizeof(sClassname), "weapon_", "");
        int entity = CreateMeleeWeapon(client, sClassname);

        // Using EquipPlayerWeapon on a properly created "CreateMeleeWeapon" will crash the server.

        if(entity == -1 || GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") != client)
        {
            entity = GivePlayerItem(client, weapon.sClassname);

            if (entity == -1)
                PrintToChat(client, "Failed to give weapon %s. This is a bug. Sorry :(", weapon.sClassname);

            else
                EquipPlayerWeapon(client, entity);
        }

        if(weapon.bActive)
            activeWeapon = entity;

        SetEntProp(entity, Prop_Send, "m_iClip1", weapon.clipAmmo);
        L4D_SetReserveAmmo(client, entity, weapon.reserveAmmo);

        // Doesn't throw error if weapon doesn't support upgrades.
        L4D2_SetWeaponUpgrades(entity, weapon.upgradeBits);
        L4D2_SetWeaponUpgradeAmmoCount(entity, weapon.upgradedAmmo);

    }

    if(activeWeapon != -1)
    {
        char sClassname[64];

        GetEdictClassname(activeWeapon, sClassname, sizeof(sClassname));

        FakeClientCommand(client, "use %s", sClassname);
    }

    return Plugin_Handled;
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
    int lastImpulse = g_iLastImpulse[client];

    g_iLastImpulse[client] = impulse;

    if(g_bSpam[client])
        return Plugin_Continue;

    if(impulse == 201 && lastImpulse != 201 && g_fNextExpireJump[client] > GetGameTime())
    {
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, rewindIndex))
        {
            
            g_iJumpCount[client] = 0;

            g_bSpam[client] = true;
            
            CreateTimer(1.0, Timer_SpamOff, client);

            RewindTime(client, 30);
        }
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(impulse == 201)
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

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    _RPG_Perks_OnPlayerSpawned(newClient, false);
}
public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
    if(priority != 0)
        return;

    _RPG_Perks_OnPlayerSpawned(client, bFirstSpawn);
}

public void _RPG_Perks_OnPlayerSpawned(int client, bool bFirstSpawn)
{
    // Cannot declare a size as it can change when we remove an Array's cell.
    for(int i=0;i < g_aHistory.Length;i++)
    {
        enHistory history;
        g_aHistory.GetArray(i, history);

        if(history.userId == GetClientUserId(client))
        {
            g_aHistory.Erase(i);
            i--;
        }
    }

    
    // Cannot declare a size as it can change when we remove an Array's cell.
    for(int i=0;i < g_aWeaponHistory.Length;i++)
    {
        enWeapon weapon;
        g_aWeaponHistory.GetArray(i, weapon);

        if(weapon.userId == GetClientUserId(client))
        {
            g_aWeaponHistory.Erase(i);
            i--;
        }
    }
}

public void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses)
{
    if(!StrEqual(identifier, "Rewind Yourself", false))
        return;

    else if(priority != 1)
        return;

    if(!GunXP_RPGShop_IsSkillUnlocked(client, rewindIndex))
    {
        maxUses = 0;

        return;
    }

    maxUses++;
}

public void RegisterSkill()
{
    UC_SilentCvar("l4d2_points_survivor_spray_alias", "");

    rewindIndex = GunXP_RPGShop_RegisterSkill("Rewind Yourself", "Rewind", "!rewind <sec> OR triple press SPRAY\nOnce per Round: Return up to 30 sec to the past, restoring mostly everything\nDoesn't restore pin, skill uses, and timed attributes",
    10000000, GunXP_RPG_GetXPForLevel(85));
}

stock int CreateMeleeWeapon(int client, const char[] sMeleeName)
{
    g_iCheckEntity = 0;

    char code[512];

    FormatEx(code, sizeof(code), "ret <- GetPlayerFromUserID(%d).GiveItem(\"%s\"); <RETURN>ret</RETURN>", GetClientUserId(client), sMeleeName);

    char sOutput[512];
    L4D2_GetVScriptOutput(code, sOutput, sizeof(sOutput));

    if (g_iCheckEntity == 0)
        return -1;

    int iWeapon    = g_iCheckEntity;
    g_iCheckEntity = -1;

    if (!IsValidEdict(iWeapon))
        return -1;

    char sClassname[64];
    GetEdictClassname(iWeapon, sClassname, sizeof(sClassname));

    // If you use EquipPlayerWeapon the server will crash :D
    // EquipPlayerWeapon(client, iWeapon);

    return iWeapon;
}