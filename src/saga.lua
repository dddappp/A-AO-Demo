local entity_coll = require("entity_coll")

local saga = {}


local ERRORS = {
    NIL_SAGA_ID_SEQUENCE = "NIL_SAGA_ID_SEQUENCE",
}


local saga_instances
local saga_id_sequence


function saga.init(_saga_instances, _saga_id_sequence)
    saga_instances = _saga_instances
    saga_id_sequence = _saga_id_sequence
end

local function next_saga_id()
    if (saga_id_sequence == nil) then
        error(ERRORS.NIL_SAGA_ID_SEQUENCE)
    end
    saga_id_sequence[1] = saga_id_sequence[1] + 1
    return saga_id_sequence[1]
end

function saga.create_saga_instance(saga_type, target, tags, context)
    local saga_id = next_saga_id()
    local s = {
        saga_id = saga_id,
        saga_type = saga_type,
        current_step = 1,
        compensating = false,
        participants = {
            {
                target = target,
                tags = tags,
            },
        },
        compensations = {},
        context = context,
    }
    local commit = function()
        entity_coll.add(saga_instances, saga_id, s)
    end
    return saga_id, commit
end

return saga
