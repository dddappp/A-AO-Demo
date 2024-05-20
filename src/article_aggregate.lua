local entity_coll = require("entity_coll")
-- local article = require("article")

local article_create_logic = require("article_create_logic")

local article_update_body_logic = require("article_update_body_logic")

local article_aggregate = {}

local ERRORS = {
    NIL_ENTITY_ID_SEQUENCE = "NIL_ENTITY_ID_SEQUENCE",
    ENTITY_ID_MISMATCH = "ENTITY_ID_MISMATCH",
    CONCURRENCY_CONFLICT = "CONCURRENCY_CONFLICT",
    VERSION_MISMATCH = "VERSION_MISMATCH",
}

article_aggregate.ERRORS = ERRORS

local article_table
local article_id_sequence
local logger


local function current_article_id()
    if (article_id_sequence == nil) then
        error(ERRORS.NIL_ENTITY_ID_SEQUENCE)
    end
    return article_id_sequence[1]
end

local function next_article_id()
    if (article_id_sequence == nil) then
        error(ERRORS.NIL_ENTITY_ID_SEQUENCE)
    end
    article_id_sequence[1] = article_id_sequence[1] + 1
    return article_id_sequence[1]
end

function article_aggregate.init(table, seq)
    article_table = table
    article_id_sequence = seq
end

function article_aggregate.set_logger(l)
    logger = l
end

function article_aggregate.create(cmd, msg, env)
    cmd.article_id = next_article_id()
    local event = article_create_logic.verify(cmd, msg, env)
    if (event.article_id ~= current_article_id()) then
        error(ERRORS.ENTITY_ID_MISMATCH)
    end
    local state = article_create_logic.new(event, msg, env)
    state.article_id = event.article_id
    entity_coll.add(article_table, state)
    if (logger) then
        logger.log(event)
    end
    return event
end

function article_aggregate.update_body(cmd, msg, env)
    local state = entity_coll.get_copy(article_table, cmd.article_id)
    -- local state = entity_coll.get(article_table, cmd.article_id)
    if (state.version ~= cmd.version) then
        error(ERRORS.CONCURRENCY_CONFLICT)
    end
    local article_id = state.article_id
    local version = state.version
    local event = article_update_body_logic.verify(state, cmd, msg, env)
    if (event.article_id ~= article_id) then
        error(ERRORS.ENTITY_ID_MISMATCH)
    end
    if (event.version ~= version) then
        error(ERRORS.VERSION_MISMATCH)
    end
    local new_state = article_update_body_logic.mutate(state, event, msg, env)
    new_state.article_id = article_id
    new_state.version = (version and version or 0) + 1
    -- state.body = 'Just for test'
    -- error("JUST FOR TEST")
    entity_coll.update(article_table, new_state)
    if (logger) then
        logger.log(event)
    end
    return event
end

return article_aggregate
