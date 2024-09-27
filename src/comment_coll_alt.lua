--[[
The "original" version of this module used a "two-dimensional" table to store article comments.
This Lua module modifies its implementation (without changing the external interface) to use a "multi-level" table to store article comments.
Specifically:
- The data_table's key is the Article ID
- The corresponding value is also a table, representing "all comments for this article"
- In this latter table, the key is the comment's Seq ID, and the value is the specific content of the comment
]]

local json = require("json")
local article_comment_id = require("article_comment_id")
local entity_coll = require("entity_coll")

local comment_coll = {}
comment_coll.__index = comment_coll

-- Private constants
local OPERATIONS = {
    ADD = "A",
    UPDATE = "U",
    ADD_OR_UPDATE = "AU",
    REMOVE = "R"
}

-- Create a new comment_coll instance
function comment_coll.new(data_table)
    local self = setmetatable({}, comment_coll)
    self.data_table = data_table or {}
    self.operation_cache = {}
    return self
end

-- Deep copy (private function)
local function deepcopy(origin)
    return entity_coll.deepcopy(origin)
end

-- Check if an entity exists
function comment_coll:contains(article_id, comment_seq_id)
    local article_comments = self.data_table[article_id]
    if not article_comments then
        return false
    end
    return article_comments[comment_seq_id] ~= nil
end

-- Add an entity
function comment_coll:add(article_id, comment_seq_id, value)
    table.insert(self.operation_cache,
        { op = OPERATIONS.ADD, article_id = article_id, comment_seq_id = comment_seq_id, value = value })
end

-- Update an entity
function comment_coll:update(article_id, comment_seq_id, value)
    table.insert(self.operation_cache,
        { op = OPERATIONS.UPDATE, article_id = article_id, comment_seq_id = comment_seq_id, value = value })
end

-- Add or update an entity
function comment_coll:add_or_update(article_id, comment_seq_id, value)
    table.insert(self.operation_cache,
        { op = OPERATIONS.ADD_OR_UPDATE, article_id = article_id, comment_seq_id = comment_seq_id, value = value })
end

-- Remove an entity
function comment_coll:remove(article_id, comment_seq_id)
    table.insert(self.operation_cache,
        { op = OPERATIONS.REMOVE, article_id = article_id, comment_seq_id = comment_seq_id })
end

-- Get a deep copy of an entity
function comment_coll:get(article_id, comment_seq_id)
    local article_comments = self.data_table[article_id]
    if not article_comments then
        return nil
    end
    local value = article_comments[comment_seq_id]
    return deepcopy(value)
end

-- Commit all cached operations
function comment_coll:commit()
    for _, operation in ipairs(self.operation_cache) do
        local article_comments = self.data_table[operation.article_id]
        if not article_comments and operation.op ~= OPERATIONS.REMOVE then
            article_comments = {}
            self.data_table[operation.article_id] = article_comments
        end

        if operation.op == OPERATIONS.ADD then
            article_comments[operation.comment_seq_id] = operation.value
        elseif operation.op == OPERATIONS.UPDATE then
            article_comments[operation.comment_seq_id] = operation.value
        elseif operation.op == OPERATIONS.ADD_OR_UPDATE then
            article_comments[operation.comment_seq_id] = operation.value
        elseif operation.op == OPERATIONS.REMOVE then
            if article_comments then
                article_comments[operation.comment_seq_id] = nil
                if next(article_comments) == nil then
                    self.data_table[operation.article_id] = nil
                end
            end
        end
    end
    -- Clear the operation cache
    self.operation_cache = {}
end

return comment_coll
