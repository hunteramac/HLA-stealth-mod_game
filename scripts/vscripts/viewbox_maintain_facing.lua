-- script runs on a view bounds that needs to maintain y rot yaw
-- This feels like an extremly inneficent way to solve the problem. but I need to prototype

local UPDATE_YAW_INTERVAL = 0.001


local view_cone = nil

function init(params)
    view_cone = params.caller
    thisEntity:SetThink(updateRot,"updateRot",UPDATE_YAW_INTERVAL)

end

function updateRot()
    --[[
    if view_cone == nil then
        return UPDATE_YAW_INTERVAL
    end

    --get rotation qangle of the viewcone/eyes --IMPORTANT-- global rotation is needed, not the local/parented version
    viewcone_rot = view_cone:GetAnglesAsVector()
    this_viewbox_rot = thisEntity:GetAnglesAsVector()

    --extract just the y rot, create a new vector with it, set thisEntity rotation to this vector
    thisEntity:SetAbsAngles(this_viewbox_rot.x,viewcone_rot.y,this_viewbox_rot.z)    
    ]]
    return UPDATE_YAW_INTERVAL
end