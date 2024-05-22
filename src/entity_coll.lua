-- local utils = require("utils")

local ERRORS = {
    ID_EXISTS = "ID_EXISTS",
    ID_NOT_EXISTS = "ID_NOT_EXISTS"
}

local entity_coll = { ERRORS = ERRORS }


local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        -- setmetatable(copy, deepcopy(getmetatable(orig)))
        setmetatable(copy, getmetatable(orig))
    else
        copy = orig
    end
    return copy
end

-- class table
-- local Articles = {}

function entity_coll.contains(table, entity_id)
    return table[entity_id] ~= nil
end

function entity_coll.add(table, entity)
    if (table[entity.article_id]) then
        error(ERRORS.ID_EXISTS)
    else
        table[entity.article_id] = entity
    end
end

function entity_coll.update(table, entity)
    if (table[entity.article_id]) then
        table[entity.article_id] = entity
    else
        error(ERRORS.ID_NOT_EXISTS)
    end
end

function entity_coll.remove(table, entity_id)
    if (table[entity_id]) then
        local removed = table[entity_id]
        table[entity_id] = nil
        return removed
    else
        error(ERRORS.ID_NOT_EXISTS)
    end
end

function entity_coll.get(table, entity_id)
    if (table[entity_id]) then
        return table[entity_id]
    else
        error(ERRORS.ID_NOT_EXISTS)
    end
end

function entity_coll.get_copy(table, entity_id)
    if (table[entity_id]) then
        return deepcopy(table[entity_id])
    else
        error(ERRORS.ID_NOT_EXISTS)
    end
end

return entity_coll
