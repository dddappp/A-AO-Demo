# Blog Example


## Prerequisites

If you want to follow us through the process of the demo, install the tools below:

* Install [aos](https://cookbook_ao.g8way.io/welcome/getting-started.html)
* Install [Docker](https://docs.docker.com/engine/install/).


## Programming


### Write DDDML Model

The model file that has been written is available at `./dddml/blog.yaml`.

For developers with some experience in OOP (Object-Oriented Programming), what the model expresses should not be difficult to understand.


> **Tip**
>
> About DDDML, here is an introductory article: ["Introducing DDDML: The Key to Low-Code Development for Decentralized Applications"](https://github.com/wubuku/Dapp-LCDP-Demo/blob/main/IntroducingDDDML.md).



### Generate Code

In repository root directory, run:

```shell
docker run --rm \
-v .:/myapp \
wubuku/dddappp-ao:latest \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```


### Filling in the business logic

Let's fill in the business operation logic written in Lua code.

> A platform-neutral expression language would be ideal in the future. Of course, we will work in this direction.

You'll notice that in the files with the suffix `_logic.lua` you need to fill in below, the signature part of the function is already written.

You only need to fill in the body of the function.


#### Modify `article_update_body_logic`

Modify the file `. /src/article_update_body_logic.lua` to fill the function body with business logic:

```lua
function article_update_body_logic.verify(_state, body, cmd, msg, env)
    return article.new_article_body_updated(_state, body)
end

function article_update_body_logic.mutate(state, event, msg, env)
    state.body = event.body
    return state
end
```


## Testing the Application


Start an aos process:

```shell
aos process_alice
```

Let's take note of its process ID, e.g. `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`.
We use the placeholder `__PROCESS_ALICE__` for it in some following example commands.


Start another aos process:

```shell
aos process_bob
```

Record its process ID, such as `0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow`.
We might use the placeholder `__PROCESS_BOB__` for it in some following example commands.

In this aos (`__PROCESS_BOB__`) process, load our application code (be wary of replacing `{PATH/TO/A-AO-Demo/src}` with the actual path):

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

It is now ready to be tested in the first process (`__PROCESS_ALICE__`) by sending messages to this `__PROCESS_BOB__` process.


### "Article" aggregate tests

In the first process (`__PROCESS_ALICE__`), check the current "article Id sequence" in the other process:

```lua
json = require("json")
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetArticleIdSequence" } })
```

You'll get a response like this:

```text
New Message From u37...zs4: Data = {"result":[0]}
```

Create a new article:

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "CreateArticle" }, Data = json.encode({ title = "title_1", body = "body_1" }) })
```

After receiving a response, check the content of the last message in the inbox:

```lua
Inbox[#Inbox]
```

Check current article Id sequence again:

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetArticleIdSequence" } })
```

View the contents of the article with ID `1` (in the `Data` property of the output message):

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetArticle" }, Data = json.encode({ article_id = "1" }) })

Inbox[#Inbox]
```

Update the body of the article with ID `1` (note that the value of `version` should match the version of the article seen above):

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "UpdateArticleBody" }, Data = json.encode({ article_id = "1", version = "0", body = "new_body_1" }) })
```

View the contents of the article with ID `1` again:

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetArticle" }, Data = json.encode({ article_id = "1" }) })

Inbox[#Inbox]
```
