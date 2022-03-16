--Legacy -- 
-- From Spring/Summer 2021 work
-- Contains View bounds LOS solving in addition to a unpolished behaviour system for a combine soldier entity.

--constants
local THINK_INTERVAL = 0.005
local PEEK_DIST_BUFFER = 2.5 --amount a player can peak out behind cover without being seenn
local STANDING_HEIGHT = 72 --base height in engine --shorter players have a slight advantage at remaining unnoticed :D
local MAX_VIEW_DISTANCE = 2000 --Max distance a combine can actually notice a player

-- Enemy filters
local FILTER_PLAYER_ENEMY = "filter_player_enemy"
local FILTER_PLAYER_NEUTRAL = "filter_player_neutral"

-- Threshold to detect vars, for vision and possibly sound
--all these vars do is set threshold of movement neccessary to push the NPC into a further state of alertness
-- it doesnt limit other ways they might enter these states
-- the only effect this has is setting how much time it takes to reset to 0, it doesnt effect build rate with how calcs setup
-- long reset times make no sense and feel implausible
-- if a motion doesnnt trigger. it this threshold should almost immediately reset by time player peeks from a different direction/place
-- weird thought IF I was showing these numbers to a player
-- aas ui. for example. I would NEED to implement some detection strategy for multiple fast pings
-- a player sstanding up and down constanntly for a minnute. feels implausible.
-- BUT this is HLA. no UI. no plaayer is going to RISK standing up and down. since part of FUZINESS game, is not knowing. accurately. when enemy will notice you.
-- it would be nice to have some means to handle it. but. very fact not known CHANGES the game.
local THRESHOLD_TO_DETECT_IDLE_SUSPICIOUS = 2
local THRESHOLD_TO_DETECT_SUSPICIOUS_ALERT = 2

local cur_detection_threshold_idle = 0
local cur_detection_threshold_suspicious = 0

-- 3 state variables that have a connection
-- a player in los must not be in cover and must be in the viewcone
-- a player in cover only matters if they are in the view cone
local player_in_los = false
local player_is_enemy = false

local player_in_cover = false

local marker_last_seen_player = nil
local view_cone = nil


local player_in_view_cone = false
local player_in_inner_bounds = false
local player_in_peripheral_bounds = false


local gaurd_state = 0
local prev_gaurd_state = 0
-- 0 -- Idle
-- 1 -- Suspicious
-- 2 -- Alert/Combat

--Undertake search routine at some point in 1-2


--perception modeling

--called via auto logic onto the target_info entity that functions as this combine's marker for last known player location
function initPlayerMarker(params)
    marker_last_seen_player = params.caller

    --isolate think functions to run at start with more view bounds
    thisEntity:SetThink(solveLOS,"solveLOS",THINK_INTERVAL)
    thisEntity:SetThink(computeAwareness,"computeAwareness",THINK_INTERVAL)
    thisEntity:SetThink(actOnStateChange,"actOnStateChange",THINK_INTERVAL)
end

function initRayShootLocation(params)
    view_cone = params.caller
end

--called by viewcone trigger when it detects the player (in the future, more then just a player EG downed allies, or suspicious activity/props)
function playerEnterViewCone(params)
    player_in_view_cone = true
end

-- if player exits the trigger, we know for sure they are out of LOS
function playerOutOfViewCone(params)
    player_in_view_cone = false
end

function playerEnterPeripheralViewBounds(params)
    player_in_peripheral_bounds = true
end

function playerExitPeripheralViewBounds(params)
    player_in_peripheral_bounds = false
end

function playerEnterInnerViewBounds(params)
    player_in_inner_bounds = true
end

function playerExitInnerViewBounds(params)
    player_in_inner_bounds = false
end

--solves if the combine has LOS of the player
-- we are trying to isolate as much funnctionnality to seperate functionsn as possible. awareness will be managed in another functionn
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
-- as part of testing this needs to produce an accurate annswer consistently
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
        return true -- if we hit nothing we definetly odd case. we should say the player is in cover if we hit nothing. least dangerous of the outputs
    end

end

--awareness modeling

--catch all. simply COMPUTES based on ANY information
function computeAwareness()
    
    prev_gaurd_state = gaurd_state

    -- I'm not sure gaurd state 2 will have any relevancy in future but it's a foundation  I know I will replace
    --nothing to compute, awareness at max. Search and combat terminate in other ways to resume idle
    if gaurd_state == 2 then
        return THINK_INTERVAL
    end

    --exception. If player ends up in primary view cone it's immediate full detection
    if player_in_los and player_in_view_cone then
        gaurd_state = 2
        return THINK_INTERVAL
    end

    if gaurd_state == 0 then
        if player_in_los then
            cur_detection_threshold_idle = cur_detection_threshold_idle + getCurrentViewBoundAwarenessBuildFactor() * THRESHOLD_TO_DETECT_IDLE_SUSPICIOUS * THINK_INTERVAL
        else
            cur_detection_threshold_idle = cur_detection_threshold_idle - THINK_INTERVAL;
        end

        cur_detection_threshold_idle = Clamp(cur_detection_threshold_idle,0,THRESHOLD_TO_DETECT_IDLE_SUSPICIOUS)

        if cur_detection_threshold_idle == THRESHOLD_TO_DETECT_IDLE_SUSPICIOUS then
            gaurd_state = 1
        end
    end

    if gaurd_state == 1 then
        if player_in_los then
            cur_detection_threshold_suspicious = cur_detection_threshold_suspicious + getCurrentViewBoundAwarenessBuildFactor() * THRESHOLD_TO_DETECT_SUSPICIOUS_ALERT * THINK_INTERVAL
        else
            cur_detection_threshold_suspicious = cur_detection_threshold_suspicious - THINK_INTERVAL;
        end

        cur_detection_threshold_suspicious = Clamp(cur_detection_threshold_suspicious,0,THRESHOLD_TO_DETECT_SUSPICIOUS_ALERT)

        if cur_detection_threshold_suspicious == THRESHOLD_TO_DETECT_SUSPICIOUS_ALERT then
            gaurd_state = 2
        end
    end

    debugAwareness()

    return THINK_INTERVAL
end

function getCurrentViewBoundAwarenessBuildFactor()
    temp = 0
   if player_in_inner_bounds then
        temp = 2
   elseif player_in_peripheral_bounds then
        temp = 1
    end

    return temp
end

function debugAwareness()
    
    if cur_detection_threshold_idle ~= 0 then
        DebugDrawText(thisEntity:GetAbsOrigin() + Vector(0,-4,80), tostring(cur_detection_threshold_idle), false, THINK_INTERVAL)
    end
    
    if cur_detection_threshold_suspicious ~= 0 then
        DebugDrawText(thisEntity:GetAbsOrigin() + Vector(0,-4,85), tostring(cur_detection_threshold_suspicious), false, THINK_INTERVAL)
    end

end

function actOnStateChange()
    --bark. then act

    if prev_gaurd_state ~= gaurd_state then

        --transistion between idle and suspicious
        if prev_gaurd_state == 0 and gaurd_state == 1 then
            --bark!
            DoEntFire(thisEntity:GetName(), "SpeakResponseConcept", "COMBINESOLDIER_HEARSUSPICIOUS", 0.0, self, self) 

            --SEARCH [ISOLATABLE BEHVAUIYR, THIS JUST HEAR FOR TESTING]
            --head towards this is just a very simple search routine. we will desire more complex ones-- 
            --alsmot playable. just make this search a bit more convincing? No, not for just MVP, if it's good enough for triple AAA. this is fine
            thisEntity:NpcForceGoPosition(marker_last_seen_player:GetAbsOrigin(),false, 0)
        end

        if prev_gaurd_state == 1 and gaurd_state == 2 then
            DoEntFire(thisEntity:GetName(), "SpeakResponseConcept", "COMBINESOLDIER_FINDENEMY", 0.0, self, self)
        end


        prev_gaurd_state = gaurd_state
    end


    if gaurd_state == 2 then
        if player_in_los and not player_is_enemy then
            makePlayerEnemy()
        end
            
        if not player_in_los and player_is_enemy then
            makePlayerNeutral()
        end
    end

    return THINK_INTERVAL
end

--helper functions
function makePlayerEnemy()
    player_is_enemy = true
    DoEntFire(thisEntity:GetName(), "SetEnemyFilter", FILTER_PLAYER_ENEMY, 0.0, self, self)
end

function makePlayerNeutral()
    player_is_enemy = false
    DoEntFire(thisEntity:GetName(), "SetEnemyFilter", FILTER_PLAYER_NEUTRAL, 0.0, self, self)
end
