-- Currently developed worked on 'stealth script'. Built from previous LOS solver.
-- rests on combine soldier entity, aim to solve player LOS and change behaviour and actions combine to reflect stealth gameplay goals.

--constants
local THINK_INTERVAL = 0.005
local PEEK_DIST_BUFFER = 2.5 --amount a player can peak out behind cover without being seen

local STANDING_HEIGHT = 72 --base height in engine --shorter players have a slight advantage at remaining unnoticed

local MAX_VIEW_DISTANCE = 2000 --Max distance a combine can actually notice a player

-- 3 state variables that have a connection
-- a player in line of sight must not be in cover and must be in the viewcone to be in LOS
-- a player in cover only matters if they are in the view cone
local player_in_los = false
local player_in_cover = false

local player_is_enemy = false

-- object storage
local marker_last_seen_player = nil
local view_cone = nil


local player_in_view_cone = false
local player_in_inner_bounds = false
local player_in_peripheral_bounds = false

--perception modeling
--called via auto logic onto the target_info entity that functions as this combine's marker for last known player location
function initPlayerMarker(params)
    marker_last_seen_player = params.caller
    --isolate think functions to run at start with more view bounds
    thisEntity:SetThink(solveLOS,"solveLOS",THINK_INTERVAL)
end

function initRayShootLocation(params)
    view_cone = params.caller
end

--called by viewcone trigger when it detects a flagged entity EG Player (in the future, more then just a player EG downed allies, or suspicious activity/props)
function entityEnterViewCone(params)
    
    if (params.activator:IsPlayer()) then
        player_in_view_cone = true
    else
        -- environment detail
    end
end

-- if no flagged entities exist in the trigger, we know for sure player is out of LOS
function allEntitiesOutOfViewCone(params)
    player_in_view_cone = false
end

-- entityEnterPeripheralViewBounds
function entityEnterPeripheralViewBounds(params)
    if (params.activator:IsPlayer()) then
        player_in_peripheral_bounds = true
    else
        -- environment detail
    end
end

function allEntitiesOutOfPeripheralViewBounds(params)
    player_in_peripheral_bounds = false
end

function entityEnterInnerViewBounds(params)
    if (params.activator:IsPlayer()) then
        player_in_inner_bounds = true
    else
        -- environment detail
    end
end

function allEntitiesOutOfInnerViewBounds(params)
    player_in_inner_bounds = false
end

--solves if the combine has LOS of the player
-- we are trying to isolate as much funnctionality to seperate functions as possible. Awareness/Behaviour will be managed in other functions
function solveLOS()
    --debugViewBounds()
    if player_in_peripheral_bounds or player_in_inner_bounds or player_in_view_cone or player_in_left_sense_bounds or player_in_right_sense_bounds then
        player_in_cover = isPlayerInCover()
        if player_in_cover then
            player_in_los = false
        else
            player_in_los = true
            marker_last_seen_player:SetAbsOrigin(player:GetAbsOrigin())
        end
    else
        player_in_los = false
    end

    return THINK_INTERVAL
end

function debugViewBounds()
    if player_in_view_cone then
        print("player in viewcone bounds")
    end

    print("----------------------------------------------")
    if (player_in_peripheral_bounds) then
        print("player in periperhal bounds")
    end

    if player_in_inner_bounds then
        print("player in inner bounds")
    end

    if player_in_left_sense_bounds then
        print("player_in_left_sense_bounds")
    end

    if player_in_right_sense_bounds then
        print("player_in_right_sense_bounds")
    end
    
    print("----------------------------------------------")
end

--uses ray traces to check if player is obscured enough
-- returns bool. 
-- as part of testing this needs to produce an accurate answer consistently
-- bug note, if combine is VERY close to a wall the player can peek around and not recive a ray when they really should. implausible
function isPlayerInCover()
    -- if the HMD litterally isnt even in the game for whatever reason (game loaded in non VR mode, very start of game breif moment headset not loaded), immediately return
    -- fixes a nil error if not present
    if player:GetHMDAvatar() == nil then
        return true
    end

    if view_cone == nill then
        return true
    end

    local trace_table_eye_to_hmd =
    {
        startpos = view_cone:GetAbsOrigin();
        endpos = player:GetHMDAvatar():GetAbsOrigin();
        ignore = thisEntity; -- script lives on the combine being controlled, we should make sure combine doesnt get blocked by themselves for whatever reason
        min = Vector(-PEEK_DIST_BUFFER,-PEEK_DIST_BUFFER,-PEEK_DIST_BUFFER);
        max = Vector(PEEK_DIST_BUFFER,PEEK_DIST_BUFFER,PEEK_DIST_BUFFER)
    }

    TraceHull(trace_table_eye_to_hmd) -- trace hull gives the player a small buffer to peek around corners without being noticed
    if trace_table_eye_to_hmd.hit then
        -- did we hit the player or cover?
        if (trace_table_eye_to_hmd.enthit == player) then 
            --we hit HMD
            DebugDrawLine(trace_table_eye_to_hmd.startpos, trace_table_eye_to_hmd.pos, 255, 0, 0, false, THINK_INTERVAL)
            return false
        else 
            --we did not hit player with tracehull
            DebugDrawLine(trace_table_eye_to_hmd.startpos,trace_table_eye_to_hmd.pos, 0, 0, 255, false, THINK_INTERVAL)

            --But is the player inside the enemies main view cone? If they are we should disable peeking since it feels really implausible as a player to peek in such close proximity and right inside the enemies view
            if player_in_view_cone then
                --do a traceline and check for collision
                local trace_table_eye_to_hmd_ignore_peek =
                {
                    startpos = view_cone:GetAbsOrigin();
                    endpos = player:GetHMDAvatar():GetAbsOrigin();
                    ignore = thisEntity; -- script lives on the combine being controlled, we should make sure combine doesnt get blocked by themselves for whatever reason
                }
                TraceLine(trace_table_eye_to_hmd_ignore_peek)
                if trace_table_eye_to_hmd_ignore_peek.hit then
                    if trace_table_eye_to_hmd_ignore_peek.enthit == player then
                        return false
                    else
                        return true
                    end
                end

                return true
            else --player not in view cone. peeking viable
                return true
            end
        end
    else
        return true -- if we hit nothing we definetly odd case. we should say the player is in cover if we hit nothing. least dangerous of the outputs to stealth gameplay
    end

end

--- Test case 1 fullfillment :: Object changed
-- called when entity detects a change in environment E.G door open when it should be closed, and so on.
function objectInLOSChanged()
    print("")
end