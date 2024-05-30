local json = require("json")
local messaging = require("messaging")
local article_aggregate = require("article_aggregate")
local test_local_tx_service = require("test_local_tx_service")


article_aggregate.init(ArticleTable, ArticleIdSequence)

test_local_tx_service.init(article_aggregate) -- ArticleTable, article_aggregate)


local function test_update_and_create_articles(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return test_local_tx_service.test_update_and_create_articles(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end

--[[
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "TestUpdateAndCreateArticles" }, Data = json.encode({ article_id_to_update = 1, version = 29, body = "new_body_29", new_article_titile = "new_article_titile"}) })
]]

Handlers.add(
    "test_update_and_create_articles",
    Handlers.utils.hasMatchingTag("Action", "TestUpdateAndCreateArticles"),
    test_update_and_create_articles
)
