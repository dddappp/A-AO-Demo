
ArticleIdSequence = ArticleIdSequence and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(ArticleIdSequence) or { 0 }

local messaging = require("messaging")


Handlers.add(
    "get_article_id_sequence",
    Handlers.utils.hasMatchingTag("Action", "GetArticleIdSequence"),
    function(msg, env, response)
        messaging.respond(true, ArticleIdSequence, msg)
    end
)
