local some_stuff = {}

function some_stuff.respond_to_dt(dt_stuff)
    if (dt_stuff["view1"]) then
        return 1    
    else
        return 2
    end
end
    
function some_stuff.add_one(x)
    -- test lua development environment on local machine
    --print("hello world")
    local x = x + 1
    return x
end

function some_stuff.minus_one(x)
    -- test lua development environment on local machine
    --print("hello world")
    local x = x - 1
    return x
end

return some_stuff