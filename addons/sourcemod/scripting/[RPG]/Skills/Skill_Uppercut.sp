
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
    name        = "Uppercut Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that lets you send a Tank flying into the sky!.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define UPPERCUT_GRAVITY -2.0
#define UPPERCUT_MIN_VELOCITY 256.0

int skillIndex;

float g_fLastHeight[MAXPLAYERS+1];
int g_iLastButtons[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

bool g_bUppercut[MAXPLAYERS+1];

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

    CreateTimer(0.2, Timer_MonitorUppercut, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


public Action Timer_MonitorUppercut(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
        {
            g_bUppercut[i] = false;
            continue;
        }
        else if(!IsPlayerAlive(i))
        {
            g_bUppercut[i] = false;
            continue;
        }

        if(GetEntityFlags(i) & FL_ONGROUND)
        {
            g_bUppercut[i] = false;
        }
    }

    return Plugin_Continue;
}
public void OnPluginStart()
{
    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


// Last Clear bad attributes.
float g_fLastClear[MAXPLAYERS+1];

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(strncmp(attributeName, "Uppercut Height Check", 21, false) == 0)
    {
        // Player cleared this attribute with Special Medkit
        if(g_fLastClear[entity] == GetGameTime())
        {
            SetEntityGravity(entity, 1.0);
            return;
        }

        float fOrigin[3];
        GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

        if(g_fLastHeight[entity] == fOrigin[2])
        {
            float fDuration = StringToFloat(attributeName[21]);

            SetEntityGravity(entity, 1.0);

            RPG_Perks_ApplyEntityTimedAttribute(entity, "Stun", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

            return;
        }

        g_fLastHeight[entity] = fOrigin[2];
        SetEntityGravity(entity, UPPERCUT_GRAVITY);

        float fVelocity[3];
        GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);

        if(fVelocity[2] <= UPPERCUT_MIN_VELOCITY)
        {
            fVelocity[2] = UPPERCUT_MIN_VELOCITY;

            TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, fVelocity);
        }

        RPG_Perks_ApplyEntityTimedAttribute(entity, attributeName, 0.2, COLLISION_SET, ATTRIBUTE_NEGATIVE);

        return;
    }
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(strncmp(attributeName, "Uppercut Height Check", 21, false) == 0)
    {
        if(oldClient == newClient)
        {
            SetEntityGravity(newClient, 1.0);
            g_fLastClear[newClient] = GetGameTime();
            return;
        }

        float fOrigin[3];
        GetEntPropVector(newClient, Prop_Data, "m_vecAbsOrigin", fOrigin);

        g_fLastHeight[newClient] = fOrigin[2];
        SetEntityGravity(newClient, UPPERCUT_GRAVITY);
        SetEntityGravity(oldClient, 1.0);
        TeleportEntity(newClient, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 285.0 }));
        return;
    }
}

public void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses)
{
    if(!StrEqual(identifier, "Uppercut", false))
        return;

    else if(priority != 1)
        return;

    if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
    {
        maxUses = 0;

        return;
    }

    maxUses++;
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == 6)
    {
        if(IsPlayer(victim) && IsPlayer(attacker))
        {
            if(g_bUppercut[victim] || g_bUppercut[attacker])
                damage = damage * 0.25;

            else if(damagetype & DMG_DROWNRECOVER)
                return;
        }
    }
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    int lastButtons = g_iLastButtons[client];

    g_iLastButtons[client] = buttons;


    if(g_bSpam[client] || L4D_GetPinnedInfected(client) != 0 || L4D_GetAttackerCarry(client) != 0 || L4D_IsPlayerStaggering(client) || IsClientAffectedByFling(client))
        return Plugin_Continue;
        
    if(buttons & IN_DUCK && !(lastButtons & IN_DUCK) && g_fNextExpireJump[client] > GetGameTime())
    {
    
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
        {
            g_iJumpCount[client] = 0;

            g_bSpam[client] = true;
            
            CreateTimer(1.0, Timer_SpamOff, client);

            int siRealm[MAXPLAYERS+1], numSIRealm;
            int ciRealm[MAXPLAYERS+1], numCIRealm;
            int witchRealm[MAXPLAYERS+1], numWitchRealm;
            int victims[MAXPLAYERS+1], numVictims;

            float fOrigin[3];
            GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

            if(RPG_Perks_IsEntityTimedAttribute(client, "Shadow Realm"))
            {
                RPG_Perks_GetZombiesInRealms(
                    _, _, siRealm, numSIRealm,
                    _, _, ciRealm, numCIRealm,
                    _, _, witchRealm, numWitchRealm);
            }
            else
            {
                RPG_Perks_GetZombiesInRealms(
                    siRealm, numSIRealm, _, _,
                    ciRealm, numCIRealm, _, _,
                    witchRealm, numWitchRealm, _, _);
            }

            for(int i=0;i < numSIRealm;i++)
            {
                int victim = siRealm[i];

                if(!IsPlayerAlive(victim))
                    continue;

                else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
                    continue;

                float fVictimOrigin[3];
                GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

                if(GetVectorDistance(fOrigin, fVictimOrigin) >= 128.0)
                    continue;

                if(GunXP_SetupAimbotStrike(client, victim, AimbotLevel_Two))
                {
                    victims[numVictims++] = victim;    
                }
            }

            if(numVictims == 0)
            {
                PrintToChat(client, "Could not find a Tank in 128u range. Use !br for context [Aimbot Level 2]");

                return Plugin_Continue;
            }

            bool success = RPG_Perks_UseClientLimitedAbility(client, "Uppercut");

            if(success)
            {
                int timesUsed, maxUses;

                RPG_Perks_GetClientLimitedAbility(client, "Uppercut", timesUsed, maxUses);

                PrintToChat(client, "Uppercut activated! (%i/%i)", timesUsed, maxUses);

                for(int i=0;i < numVictims;i++)
                {
                    int victim = victims[i];

                    float fVictimOrigin[3];
                    GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

                    g_fLastHeight[victim] = fVictimOrigin[2];
                    SetEntityGravity(victim, UPPERCUT_GRAVITY);
                    TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 285.0 }));
                    
                    float fDuration = 1.0;

                    char attributeName[64];
                    FormatEx(attributeName, sizeof(attributeName), "Uppercut Height Check%i", RoundFloat(fDuration));

                    RPG_Perks_ApplyEntityTimedAttribute(victim, attributeName, 0.2, COLLISION_SET, ATTRIBUTE_NEGATIVE);

                    g_bUppercut[victim] = true;
                }

                float fVelocity[3];
                GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);

                fVelocity[2] += 550.0;

                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);

                int clientsRealm[MAXPLAYERS+1], numClientsRealm;

                if(RPG_Perks_IsEntityTimedAttribute(client, "Shadow Realm"))
                {
                    RPG_Perks_GetClientsInRealms(_, _, clientsRealm, numClientsRealm);
                }
                else    
                {
                    RPG_Perks_GetClientsInRealms(clientsRealm, numClientsRealm, _, _);
                }

                for(int i=0;i < numClientsRealm;i++)
                {
                    int target = clientsRealm[i];

                    if(!IsClientInGame(target))
                        continue;

                    float fTargetOrigin[3];
                    GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", fTargetOrigin);

                    if(GetVectorDistance(fOrigin, fTargetOrigin) <= 1000.0)
                    {
                        ClientCommand(target, "play player/tank/hit/hulk_punch_1");
                    }
                }
            }
        }

        return Plugin_Continue;
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(buttons & IN_DUCK)
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

public void RegisterSkill()
{
    skillIndex = GunXP_RPGShop_RegisterSkill("Uppercut", "Uppercut", "Triple click CROUCH to Uppercut a Tank into the sky\nUntil landing, Tank deals and takes 75{PERCENT} less damage.",
    1700, GunXP_RPG_GetXPForLevel(37));
}


bool IsClientAffectedByFling(int client)
{
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);
	switch (model[29])
	{
		case 'b':    // nick
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 661, 667, 669, 671, 672, 627, 628, 629, 630, 620:
					return true;
			}
		}
		case 'd':    // rochelle
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 668, 674, 676, 678, 679, 635, 636, 637, 638, 629:
					return true;
			}
		}
		case 'c':    // coach
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 650, 656, 658, 660, 661, 627, 628, 629, 630, 621:
					return true;
			}
		}
		case 'h':    // ellis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 665, 671, 673, 675, 676, 632, 633, 634, 635, 625:
					return true;
			}
		}
		case 'v':    // bill
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 753, 759, 761, 763, 764, 535, 536, 537, 538, 528:
					return true;
			}
		}
		case 'n':    // zoey
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 813, 819, 821, 823, 824, 544, 545, 546, 547, 537:
					return true;
			}
		}
		case 'e':    // francis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 756, 762, 764, 766, 767, 538, 539, 540, 541, 531:
					return true;
			}
		}
		case 'a':    // louis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 753, 759, 761, 763, 764, 535, 536, 537, 538, 528:
					return true;
			}
		}
	}
	return false;
}