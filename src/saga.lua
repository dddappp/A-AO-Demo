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

function saga.get_saga_instance(saga_id)
    return entity_coll.get(saga_instances, saga_id)
end

function saga.get_saga_instance_copy(saga_id)
    return entity_coll.get_copy(saga_instances, saga_id)
end

function saga.contains_saga_instance(saga_id)
    return entity_coll.contains(saga_instances, saga_id)
end

function saga.create_saga_instance(saga_type, target, tags, context, original_message)
    local saga_id = next_saga_id()
    local s = {
        saga_id = saga_id,
        saga_type = saga_type,
        current_step = 1,
        compensating = false,
        completed = false,
        participants = {
            {
                target = target,
                tags = tags,
            },
        },
        compensations = {},
        context = context,
        original_message = original_message,
    }
    local commit = function()
        entity_coll.add(saga_instances, saga_id, s)
    end
    return saga_id, commit
end

-- --- Increase saga instance's current_step
-- function saga.increment_saga_instance_current_step(saga_id)
--     local s = saga.get_saga_instance_copy(saga_id)
--     s.current_step = s.current_step + 1
--     local commit = function()
--         entity_coll.update(saga_instances, saga_id, s)
--     end
--     return commit
-- end

-- --- Decrease saga instance's current_step
-- function saga.decrement_saga_instance_current_step(saga_id)
--     local s = saga.get_saga_instance_copy(saga_id)
--     s.current_step = s.current_step - 1
--     local commit = function()
--         entity_coll.update(saga_instances, saga_id, s)
--     end
--     return commit
-- end

--- Move saga instance's current_step forward and record participant information
function saga.move_saga_instance_forward(saga_id, step, target, tags, context)
    local s = saga.get_saga_instance_copy(saga_id)
    for _ = 1, step - 1, 1 do
        s.current_step = s.current_step + 1
        s.participants[s.current_step] = {} -- invoke local
    end
    s.current_step = s.current_step + 1
    s.participants[s.current_step] = {
        target = target,
        tags = tags,
    }
    s.context = context
    local commit = function()
        entity_coll.update(saga_instances, saga_id, s)
    end
    return commit
end

function saga.rollback_saga_instance(saga_id, step, target, tags, context, error)
    local s = saga.get_saga_instance_copy(saga_id)
    s.compensating = true
    for _ = 1, step - 1, 1 do
        s.current_step = s.current_step - 1
        s.compensations[#s.compensations + 1] = {} -- invoke local or empty step
    end
    s.current_step = s.current_step - 1
    s.compensations[#s.compensations + 1] = target and {
        target = target,
        tags = tags or {},
    } or {}
    if (s.current_step <= 1) then
        s.completed = true
    end
    if context then
        s.context = context
    end
    if error then
        s.error = tostring(error)
    end
    local commit = function()
        entity_coll.update(saga_instances, saga_id, s)
    end
    return commit
end

--- Complete saga instance
function saga.complete_saga_instance(saga_id, context)
    local s = saga.get_saga_instance_copy(saga_id)
    s.completed = true
    s.context = context
    local commit = function()
        entity_coll.update(saga_instances, saga_id, s)
    end
    return commit
end

return saga
