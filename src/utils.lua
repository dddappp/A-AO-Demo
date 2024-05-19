local utils = {}

function utils.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.deepcopy(orig_key)] = utils.deepcopy(orig_value)
        end
        -- setmetatable(copy, Utils.deepcopy(getmetatable(orig)))
        setmetatable(copy, getmetatable(orig))
    else
        copy = orig
    end
    return copy
end

return utils
