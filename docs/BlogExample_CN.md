# 博客示例


## 前置条件

如果你想跟随我们走一遍演示的流程，请安装下面的工具：

* 安装 [aos](https://cookbook_ao.g8way.io/welcome/getting-started.html)
* 安装 [Docker](https://docs.docker.com/engine/install/).


## 编码

### 编写 DDDML 模型

已经编写好的模型文件见 `./dddml/blog.yaml`.

对于稍有 OOP（面向对象编程）经验的开发者来说，模型所表达的内容应该不难理解。


> **提示**
>
> 关于 DDDML，这里有个介绍文章：["Introducing DDDML: The Key to Low-Code Development for Decentralized Applications"](https://github.com/wubuku/Dapp-LCDP-Demo/blob/main/IntroducingDDDML.md).


### 生成代码

在代码库的根目录执行：

```shell
docker run --rm \
-v .:/myapp \
wubuku/dddappp-ao:latest \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```

### 填充业务逻辑

下面让我们填充以 Lua 代码编写的业务操作逻辑。

> 理想情况下，未来应该有一门平台中立的表达式语言，让开发者可以更方便的编写“多链”应用的业务逻辑。当然，我们还在朝这个方向努力。

你会发现，下面需要填充业务逻辑实现的后缀名为 `_logic.lua` 的文件中，函数的签名部分已经写好了，你只需要填充函数体部分。

#### 修改 `article_update_body_logic`

修改文件 `./src/article_update_body_logic.lua`，在函数体中填充业务逻辑：

```lua
function article_update_body_logic.verify(_state, body, cmd, msg, env)
    return article.new_article_body_updated(_state, body)
end

function article_update_body_logic.mutate(state, event, msg, env)
    state.body = event.body
    return state
end
```


## 测试应用

启动一个 aos 进程：

```shell
aos process_bob
```

让我们把这个进程称为 `PROCESS_BOB`。
在这个 aos 进程中，装载我们的应用代码（注意将 `{PATH/TO/A-AO-Demo/src}` 替换为实际的路径）：

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```


### “文章”相关的测试

你可以在 `PROCESS_BOB` 进程中执行以下测试代码。
其实，你还可以启动另外一个 aos 进程，比如 `aos process_alice`，然后在这个 `PROCESS_ALICE` 进程中执行下面的测试。
不过，需要注意的是，在 `PROCESS_ALICE` 进程中执行测试时，需要将 `Send` 函数中的 `Target` 参数的值替换为 `PROCESS_BOB` 的进程 ID。


查看当前“文章的序号”：

```lua
json = require("json")
Send({ Target = ao.id, Tags = { Action = "GetArticleIdSequence" } })
```

你会收到类似这样的回复：

```text
New Message From u37...zs4: Data = {"result":[0]}
```

创建一篇新文章：

```lua
Send({ Target = ao.id, Tags = { Action = "CreateArticle" }, Data = json.encode({ title = "title_1", body = "body_1" }) })
```

在收到回复后，查看最后一条收件箱消息的内容：

```lua
Inbox[#Inbox]
```

再次查看当前“文章的序号”：

```lua
Send({ Target = ao.id, Tags = { Action = "GetArticleIdSequence" } })
```

查看序号为 `1` 的文章的内容（在输出消息的 `Data` 属性中）：

```lua
Send({ Target = ao.id, Tags = { Action = "GetArticle" }, Data = json.encode({ article_id = 1 }) })

Inbox[#Inbox]
```

更新序号为 `1` 的文章（注意 `version` 的值应该与上面看到的当前文章的版本号一致）：

```lua
Send({ Target = ao.id, Tags = { Action = "UpdateArticle" }, Data = json.encode({ article_id = 1, version = 0, title = "new_title_1", body = "new_body_1" }) })
```


再次查看序号为 `1` 的文章的内容：

```lua
Send({ Target = ao.id, Tags = { Action = "GetArticle" }, Data = json.encode({ article_id = 1 }) })

Inbox[#Inbox]
```

使用 DDDML 模型中定义的 `UpdateBody` 方法更新文章的正文：

```lua
Send({ Target = ao.id, Tags = { Action = "UpdateArticleBody" }, Data = json.encode({ article_id = 1, version = 0, body = "new_body_1" }) })
```

### “评论”相关的测试

添加评论：

```lua
Send({ Target = ao.id, Tags = { Action = "AddComment" }, Data = json.encode({ article_id = 1, commenter = "alice", body = "comment_body_1" }) })
```

查看评论信息：

```lua
Send({ Target = ao.id, Tags = { Action = "GetComment" }, Data = json.encode({ article_comment_id = { article_id = 1, comment_seq_id = 1 } }) })

Inbox[#Inbox]
```

