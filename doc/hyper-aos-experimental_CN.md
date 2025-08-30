# Hyper AOS Experimental 测试

### 使用 aos 启动进程

执行：

```bash
aos {PROCESS_NAME} --url http://node.arweaveoasis.com:8734 
```

选择 `hyper-aos (experimental)`。

### 测试 ping-pong

先启动第一个进程，我们把这个进程叫做 Alice。

```bash
aos alice --url http://node.arweaveoasis.com:8734 
```

为了允许特定的账户向这个进程发送消息，在这个进程的 aos 提示符中执行：

```lua
table.insert(authorities, owner)
-- 可以键入 owner 来查看 owner 的值
```

在 aos 提示符中先输入 `.editor`，启动内嵌的编辑器。然后输入：

```lua
Handlers.add(
  "ping2",
  "ping2",
  function(msg)
    print("ping2, from ", msg.from)
  end
)
```

然后输入 `.done` 来完成编辑并执行。

可以查看 id（进程 ID）变量的值：

```lua
id
```

假设进程 ID 是 `G3ySMDOWElvSQviopxTHdRRDs0TwPCkcs_NstkJqN88`，下面会用这个 ID 来测试。

---

启动另外一个进程，我们把这个进程叫做 Bob。

```bash
aos bob --url http://node.arweaveoasis.com:8734 
```

在这个进程的 aos 提示符中执行：

```lua
table.insert(authorities, owner)

PROCESS_ID_ALICE = "G3ySMDOWElvSQviopxTHdRRDs0TwPCkcs_NstkJqN88"

send({ target = PROCESS_ID_ALICE, action = "ping2", data = "ping2" })
```

---

回到 Alice 进程，如果没有问题，应该可以看到类似下面的输出：

```
ping2, from 	u0ZgZipiNvvAhGaDlMkiaY0GEMYT_11PCXspUox0RiY
true
```

这表示 Alice 进程收到了 Bob 进程发送的 "ping2" 消息。

继续改进 Alice 进程中的代码，键入 `.editor` 来启动内嵌的编辑器，然后输入：

```lua
Handlers.add(
  "ping2",
  "ping2",
  function(msg)
    print("ping2, from ", msg.from)
    send({ target = msg.from, action = "pong2", data = "pong2" })
  end
)
```

也就是说，我们给 "ping2" 这个消息处理器的代码增加了一行代码，逻辑是：向消息的来源进程发送 "pong2" 回应消息。

---

切换到 Bob 进程，键入 `.editor` 来启动内嵌的编辑器，然后输入：

```lua
Handlers.add(
  "pong2",
  "pong2",
  function(msg)
    print("pong2, from ", msg.from)
  end
)
```

然后输入 `.done` 来完成编辑并执行。

接着在 Bob 进程中执行：

```lua
send({ target = PROCESS_ID_ALICE, action = "ping2", data = "ping2" })
```

应该能看到类似下面的输出：

```
pong2, from 	G3ySMDOWElvSQviopxTHdRRDs0TwPCkcs_NstkJqN88
true
```

这表示 Bob 进程收到了 Alice 进程的回应消息。


### Tips

和之前的 aos 不同之处：

- 访问 `ao` 模块不再使用 `ao.` 前缀，直接访问即可。比如：
  - 原来是 `ao.id`，改为 `id`。
  - 原来是 `ao.send`，改为 `send`。
  - 使用 `authorities` 而不是 `ao.authorities`。
- 消息的属性名从大写开头改为小写开头（可以使用 `Inbox[#Inbox]` 查看消息的属性）。比如：
  - 原来是 `msg.From`，改为 `msg.from`。
  - 原来是 `msg.Data`，改为 `msg.data`。




