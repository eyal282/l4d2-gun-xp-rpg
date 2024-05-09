
#include <GunXP-RPG>
#include <ps_api>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
    name        = "Superman Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill for flying for 10 seconds once per round.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int g_iLastCollisionGroup[MAXPLAYERS+1] = { -1, ... };

int supermanIndex;

int g_iLastImpulse[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

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

public void OnMapStart()
{
    for(int i=0;i < sizeof(g_fNextExpireJump);i++)
    {
        g_fNextExpireJump[i] = 0.0;

        g_iJumpCount[i] = 0;
    }
}

public void OnPluginEnd()
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(g_iLastCollisionGroup[i] == -1)
            continue;

        SetEntProp(i, Prop_Send, "m_CollisionGroup", g_iLastCollisionGroup[i]);
    }
}
public void OnPluginStart()
{
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public Action Event_WeaponFire(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if(weapon == -1)
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, supermanIndex))
        return Plugin_Continue;

    SetEntProp(weapon, Prop_Send, "m_iClip1", 11);

    return Plugin_Continue;
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority != 0)
        return;

    else if(!RPG_Perks_IsEntityTimedAttribute(victim, "No fall damage"))
        return;

    else if(!(damagetype & DMG_FALL))
        return;

    bImmune = true;

}

public void RPG_Perks_OnTimedAttributeStart(int attributeEntity, char attributeName[64])
{
    if(StrEqual(attributeName, "Superman"))
    {
        if(IsPlayer(attributeEntity))
        {
            float fDuration = 0.0;

            if(!RPG_Perks_IsEntityTimedAttribute(attributeEntity, "Superman", fDuration) && fDuration == 0.0)
                return;

            RPG_Perks_ApplyEntityTimedAttribute(attributeEntity, "Invincible", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);
            RPG_Perks_ApplyEntityTimedAttribute(attributeEntity, "Immolation", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);
            RPG_Perks_ApplyEntityTimedAttribute(attributeEntity, "Stun", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);

            g_iLastCollisionGroup[attributeEntity] = GetEntProp(attributeEntity, Prop_Send, "m_CollisionGroup");

            // Debris, prevents collision and also prevents counting as a Special Infected for the Safe Room count.       
            SetEntProp(attributeEntity, Prop_Send, "m_CollisionGroup", 1);

            int pinner = L4D_GetPinnedInfected(attributeEntity);

            if(pinner != 0)
            {
                ClientCommand(attributeEntity, "play weapons/knife/knife_deploy.wav");

                switch(RPG_Perks_GetZombieType(pinner))
                {
                    case ZombieType_Smoker: L4D_Smoker_ReleaseVictim(attributeEntity, pinner);
                    case ZombieType_Hunter: L4D_Hunter_ReleaseVictim(attributeEntity, pinner);
                    case ZombieType_Jockey: L4D2_Jockey_EndRide(attributeEntity, pinner);
                    case ZombieType_Charger:
                    {
                        if(L4D_GetVictimCarry(pinner) == attributeEntity)
                            L4D2_Charger_EndCarry(attributeEntity, pinner);

                        else
                            L4D2_Charger_EndPummel(attributeEntity, pinner);
                    }
                }

                RPG_Perks_TakeDamage(pinner, attributeEntity, attributeEntity, 10000.0, DMG_SLASH);
            }

            PSAPI_FullHeal(attributeEntity);
        }
    }
}


public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(!StrEqual(attributeName, "Superman"))
        return;

    else if(oldClient == newClient)
        return;

    g_iLastCollisionGroup[newClient] = g_iLastCollisionGroup[oldClient];
    g_iLastCollisionGroup[oldClient] = -1;

    SetEntProp(newClient, Prop_Send, "m_CollisionGroup", g_iLastCollisionGroup[newClient]);
}
public void RPG_Perks_OnTimedAttributeExpired(int attributeEntity, char attributeName[64])
{
    if(StrEqual(attributeName, "Superman"))
    {
        if(IsPlayer(attributeEntity))
        {
            SetEntProp(attributeEntity, Prop_Send, "m_CollisionGroup", g_iLastCollisionGroup[attributeEntity]);

            RPG_Perks_ApplyEntityTimedAttribute(attributeEntity, "No fall damage", 10.0, COLLISION_SET_IF_HIGHER, ATTRIBUTE_POSITIVE);
        }
    }
}

public void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses)
{
    if(!StrEqual(identifier, "Superman", false))
        return;

    else if(priority != 1)
        return;

    if(!GunXP_RPGShop_IsSkillUnlocked(client, supermanIndex))
    {
        maxUses = 0;

        return;
    }

    maxUses++;
}

stock void VelocityByAim(int client, float fSpeed, bool bUseFwd, float fVec[3])
{
    float eyeOrigin[3], eyeAngles[3], vecFwd[3];

    GetClientEyePosition(client, eyeOrigin);
    GetClientEyeAngles(client, eyeAngles);

    if(bUseFwd)
        GetAngleVectors(eyeAngles, vecFwd, NULL_VECTOR, NULL_VECTOR);

    else
        GetAngleVectors(eyeAngles, NULL_VECTOR, vecFwd, NULL_VECTOR);

    NormalizeVector(vecFwd, vecFwd);
    ScaleVector(vecFwd, fSpeed);

    fVec = vecFwd;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
    CheckSupermanActivation(client, buttons, impulse);

    if(!RPG_Perks_IsEntityTimedAttribute(client, "Superman"))
        return Plugin_Continue;

    if(GetEntityFlags(client) & FL_ONGROUND)
    {
        float fOrigin[3];
        GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

        if(!IsPlayerStuck(client, fOrigin, 20.0))
        {   
            fOrigin[2] += 20.0;

            TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);
        }
    }
    float fFinalVelocity[3];

    float fSpeed = 768.0;

    if(buttons & IN_SPEED)
        fSpeed /= 1.5;

    if(buttons & IN_DUCK)
        fSpeed /= 2.0;

    fFinalVelocity[2] = 10.0;

    if(buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT)
    {
        if(buttons & IN_FORWARD && buttons & IN_BACK)
        {
            buttons &= ~IN_FORWARD;
            buttons &= ~IN_BACK;
        }

        if(buttons & IN_MOVERIGHT && buttons & IN_MOVELEFT)
        {
            buttons &= ~IN_MOVERIGHT;
            buttons &= ~IN_MOVELEFT;
        }

        float fVelocity[3];

        if(buttons & IN_FORWARD)
        {
            VelocityByAim(client, fSpeed, true, fVelocity);
            AddVectors(fVelocity, fFinalVelocity, fFinalVelocity);
        }

        if(buttons & IN_BACK)
        {
            VelocityByAim(client, -1 * fSpeed, true, fVelocity);
            AddVectors(fVelocity, fFinalVelocity, fFinalVelocity);
        }

        if(buttons & IN_MOVERIGHT)
        {
            VelocityByAim(client, 0.9 * fSpeed, false, fVelocity);
            AddVectors(fVelocity, fFinalVelocity, fFinalVelocity);
        }

        if(buttons & IN_MOVELEFT)
        {
            VelocityByAim(client, -0.9 * fSpeed, false, fVelocity);
            AddVectors(fVelocity, fFinalVelocity, fFinalVelocity);
        }
    }

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fFinalVelocity);

    return Plugin_Continue;
}

stock void CheckSupermanActivation(int client, int buttons, int impulse)
{
    int lastImpulse = g_iLastImpulse[client];

    g_iLastImpulse[client] = impulse;

    if(g_bSpam[client])
        return;

    if(impulse == 201 && lastImpulse != 201 && g_fNextExpireJump[client] > GetGameTime())
    {
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, supermanIndex))
        {
            
            g_iJumpCount[client] = 0;

            g_bSpam[client] = true;
            
            CreateTimer(1.0, Timer_SpamOff, client);

            bool success = RPG_Perks_UseClientLimitedAbility(client, "Superman");

            if(success)
            {
                float fDuration = 60.0;

                bool bTanks = false;

                for(int i=1;i <= MaxClients;i++)
                {
                    if(!IsClientInGame(i))
                        continue;

                    else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
                        continue;

                    bTanks = true;
                }

                if(bTanks)
                    fDuration = 12.0;

                int timesUsed, maxUses;

                RPG_Perks_GetClientLimitedAbility(client, "Superman", timesUsed, maxUses);

                PrintToChat(client, "Superman is active for %.0f sec (%i/%i)", fDuration, timesUsed, maxUses);

                RPG_Perks_ApplyEntityTimedAttribute(client, "Superman", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);
            }
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
}

public Action Timer_SpamOff(Handle Timer, int client)
{
    g_bSpam[client] = false;

    return Plugin_Continue;
}

public void RegisterSkill()
{
    UC_SilentCvar("l4d2_points_survivor_spray_alias", "");

    supermanIndex = GunXP_RPGShop_RegisterSkill("Superman", "Superman", "Infinite Ammo.\nOnce per Round: Triple click SPRAY to activate Superman, INVINCIBLE, and Immolation\nDuration is 12 sec, or for 1 min if Tank isn't alive.\nYou will be able to fly around at high speed with collisions enabled",
    GunXP_RPG_GetXPForLevel(85), GunXP_RPG_GetXPForLevel(85));
}
