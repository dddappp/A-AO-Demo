local entity_coll = require("entity_coll")

local test_local_tx_service = {}

-- local article_table
local article_aggregate

function test_local_tx_service.init( --_article_table,
    _article_aggregate
)
    -- article_table = _article_table
    article_aggregate = _article_aggregate
end

function test_local_tx_service.test_update_and_create_articles(cmd, msg, env)
    local article_id_to_update = cmd.article_id_to_update
    -- local version = entity_coll.get(article_table, article_id_to_update).version
    local version = cmd.version
    local body = cmd.body
    local _, commmit_1 = article_aggregate.update_body(
        { article_id = article_id_to_update, version = version, body = body }, msg, env
    )
    local new_article_titile = cmd.new_article_titile
    local _, commmit_2 = article_aggregate.create({ title = new_article_titile, body = "no-body", owner = "" }, msg, env)
    return {}, function()
        commmit_1()
        -- error("rollback") -- ONLY for testing
        commmit_2()
    end
end

return test_local_tx_service
