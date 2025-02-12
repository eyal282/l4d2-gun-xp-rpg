stock bool TeleportAroundTarget(int client, int target, float additionalRadius = 0.0)
{
    float targetPos[3], anglePos[3];
    float startAngle = GetRandomFloat(0.0, 360.0);
    
    float targetMins[3], targetMaxs[3];
    GetEntPropVector(target, Prop_Send, "m_vecMins", targetMins);
    GetEntPropVector(target, Prop_Send, "m_vecMaxs", targetMaxs);
    
    float clientMins[3], clientMaxs[3];
    GetEntPropVector(client, Prop_Send, "m_vecMins", clientMins);
    GetEntPropVector(client, Prop_Send, "m_vecMaxs", clientMaxs);
    
    float targetRadius = (targetMaxs[0] - targetMins[0]);
    float clientRadius = (clientMaxs[0] - clientMins[0]);
    float radius = (targetRadius + clientRadius) * 0.5 + additionalRadius;
    
    GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetPos);
    
    PrintToServer("Target Mins: %.1f %.1f %.1f", targetMins[0], targetMins[1], targetMins[2]);
    PrintToServer("Target Maxs: %.1f %.1f %.1f", targetMaxs[0], targetMaxs[1], targetMaxs[2]);
    PrintToServer("Client Mins: %.1f %.1f %.1f", clientMins[0], clientMins[1], clientMins[2]);
    PrintToServer("Client Maxs: %.1f %.1f %.1f", clientMaxs[0], clientMaxs[1], clientMaxs[2]);
    PrintToServer("Target Position: %.1f %.1f %.1f", targetPos[0], targetPos[1], targetPos[2]);
    PrintToServer("Calculated Radius: %.1f", radius);
    
    for(float angle = startAngle; angle < startAngle + 360.0; angle += 22.5)
    {
        anglePos[0] = targetPos[0] + (radius * Cosine(DegToRad(angle)));
        anglePos[1] = targetPos[1] + (radius * Sine(DegToRad(angle)));
        anglePos[2] = targetPos[2];
        
        PrintToServer("Trying angle %.1f at position: %.1f %.1f %.1f", angle, anglePos[0], anglePos[1], anglePos[2]);
        TR_TraceHullFilter(anglePos, anglePos, clientMins, clientMaxs, MASK_PLAYERSOLID, TraceFilter_IgnoreSelf, client);
        PrintToServer("Trace hit: %d", TR_DidHit());
        
        if(!TR_DidHit())
        {
            float angles[3];
            MakeVectorFromPoints(anglePos, targetPos, angles);
            GetVectorAngles(angles, angles);
            angles[0] = 0.0;
            angles[2] = 0.0;
            
            TeleportEntity(client, anglePos, angles, NULL_VECTOR);
            return true;
        }
    }
    
    return false;
}
