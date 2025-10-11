# SAGA修复进度跟踪文档


## 📋 任务目标
修复AO Saga框架，使其能够在AO Tag过滤机制下正常工作。

## 🎯 问题背景

@README_CN.md 描述的两进程 （alice 和 bob）Saga 测试在 ao 对 Tags 进行过滤前，是实际测试通过的！
我们目前面临的问题是：在 ao 版本更新后，增加了对 Tags 的过滤，导致原来已经通过测试的 Saga 执行过程失败。
为此我们需要找到替代方案的问题。（分析讨论参考： @SAGA-TECHNICAL-ANALYSIS.md ）

> NOTE：以下测试是在提交 `615b9a11a3b1f18deea99e255f9a4ac1da1f0073` 前，所做的测试。而此后的代码修改，即是尝试使用 Data 嵌入 Saga 信息来解决问题。

从失败的测试记录
@process_alice_1008.txt @process_alice_1008.txt 
来看：bob 进程已经开始执行 Saga，然后向 alice 进程发出了 “查询库存请求”，并且收到了回复：

```
Data = "{"result":{"version":0,"quantity":100,"inventory_item_id":{"location":"y","product_id":1},"entries":[{"...
```

测试呈现出来的问题是：
因为尝试使用消息的 Tags 来传递的 Saga 信息发生丢失（被 ao 新版本过滤掉了），导致 Saga 无法推进到下一步。
比如，如果回复的消息中没有 Action 信息，就会导致无法触发（接收消息的进程中的） handler 的处理逻辑，而未被处理的消息就会出现在 Inbox 中。

> NOTE：以 DDDML 工具为“方法”生成的代码来说，如果要想让方法的回复消息出现在一个进程 Inbox 里，可以在该进程（姑且称之为“原进程”）内用 eval 的方式来发送“调用方法”的消息。
> 这样收到消息的进程就会从消息的 From 字段中看到发送消息的进程 ID，然后将执行结果回复给这个 ID 指向的进程。
> 如果收到消息的进程（原进程）没有 handler 可以处理消息，消息就会出现在原进程的 Inbox 中。
> 可以查看示例 @ao-cli-non-repl/tests/run-blog-tests.sh

我们在 @SAGA-TECHNICAL-ANALYSIS.md 中分析了这个问题。
所以才导致了本次任务的一系列的代码修改——尝试使用在消息的 Data 中嵌入 Saga 消息以代替在 Tags 中包含 Saga 信息的“旧做法”。

综上所述：
- **原始状态**: README_CN.md描述的alice-bob两进程SAGA测试曾经通过
- **当前问题**: AO版本更新后，Tag过滤机制导致SAGA无法推进
- **核心原因**: 自定义Tag（如X-SagaId）在跨进程传递时被AO系统过滤
- **解决方案**: 使用Data嵌入替代Tag传递Saga信息

实现过程中我们需要注意两个关键点：
- Saga ID（`X-SagaID`）是否在 Saga 的执行过程中是否被正确“维护”（没有中途丢失）？
- 接收消息的进程是否可以获取到“回复消息的 Action”（`X-ResponseAction`），以及在发送回复消息时是否正确设置了 Action？

## 🔍 关键发现记录

### 发现 #1: Action Tag可以正常传递 ✅
**时间**: 2025-01-10
**测试**: test_process_a.lua + test_process_b.lua
**结论**: 
- Action可以作为Tag正常传递（`Tags = { Action = "..." }`）
- Action也可以作为直接属性传递（`message.Action = "..."`）
- AO会自动在两种形式间转换
- 当同时设置时，值会交叉（发送Action=A,Tags.Action=B，接收Action=B,Tags.Action=A）

**测试证据**:
```json
{
  "test": "Test1_ActionInTags",
  "action_in_tags": "TestActionInTags",
  "action_direct": "TestActionInTags"
}
```

**重要性**: ⭐⭐⭐⭐⭐
**影响**: 这意味着之前认为"Action被过滤"的结论是错误的！Handler匹配应该可以正常工作！

### 发现 #2: SAGA已经推进到步骤2 ✅
**时间**: 2025-01-10
**测试**: 手动调试alice-bob测试
**结论**:
- SAGA Instance当前在步骤2（`current_step: 2`）
- 步骤1的callback（GetInventoryItem）已经成功触发
- 问题出在步骤2的callback（CreateSingleLineInOut）未被触发

**测试证据**:
```bash
ao-cli eval "$BOB" --data "saga = require('saga'); local inst = saga.get_saga_instance_copy(1); return inst and inst.current_step or 0"
# 输出: "2"
```

**重要性**: ⭐⭐⭐⭐⭐
**影响**: SAGA核心逻辑是工作的！问题可能不在Action传递，而在其他地方！

### 发现 #3: Callback Handler报错 INVALID_MESSAGE ✅
**时间**: 2025-01-10
**测试**: 添加错误追踪到callback handler
**结论**:
- 手动发送GetInventoryItem callback时报错 `INVALID_MESSAGE`
- 错误发生在 `inventory_service.lua:100` 的检查：
  ```lua
  if (saga_instance.current_step ~= 1 or saga_instance.compensating) then
      error(ERRORS.INVALID_MESSAGE)
  end
  ```
- 因为SAGA已经在步骤2，所以检查失败

**测试证据**:
```json
{
  "error": "[string \"aos\"]:1843: INVALID_MESSAGE",
  "time": 1760086448414
}
```

**重要性**: ⭐⭐⭐⭐
**影响**: 这证明了SAGA在第一次真实的callback时已经推进到步骤2！说明步骤1成功了！

### 发现 #4: Alice有CreateSingleLineInOut handler ✅
**时间**: 2025-01-10
**测试**: 检查alice进程的handlers
**结论**: alice确实有`create_single_line_in_out` handler

**重要性**: ⭐⭐⭐
**影响**: Handler存在，问题可能在消息传递或handler触发条件

## 🚧 当前问题分析

### 问题焦点: 为什么步骤2卡住了？

**已知信息**:
1. ✅ Action可以正常传递
2. ✅ 步骤1成功完成（SAGA推进到步骤2）
3. ✅ alice有CreateSingleLineInOut handler
4. ❓ 步骤2的callback未被触发

**可能原因**:
1. **消息未发送**: bob未向alice发送CreateSingleLineInOut请求
2. **消息未到达**: 消息发送了但alice未收到
3. **Handler未匹配**: 消息到达但handler匹配失败
4. **Handler执行失败**: handler匹配但执行时出错

### 发现 #5: GetInventoryItem Callback从未被调用！🔥
**时间**: 2025-01-10
**测试**: 添加DEBUG_LOG追踪callback调用
**结论**:
- 新创建的SAGA实例2，current_step=1
- GetInventoryItem callback未被调用（DEBUG_LOG为空）
- 用户确认：在修改代码前，这些步骤都是工作的！

**重要性**: ⭐⭐⭐⭐⭐
**影响**: 代码逻辑检查：
1. ✅ bob的SAGA启动代码正确地嵌入Saga信息到request Data中
2. ✅ `messaging.commit_send_or_error` -> `send` 正确发送Data和Tags
3. ✅ alice的handler正确提取Saga信息并处理
4. ✅ `messaging.respond`正确嵌入Saga信息到response Data并设置Action tag
5. ❓ bob的callback handler定义是否正确？

### 发现 #6: 关键疑点 - callback handler的匹配逻辑 🔥
**时间**: 2025-01-10
**怀疑**: 我们修改了callback handlers使用`messaging.hasMatchingDataAction`，但测试证明Action可以正常传递！
**需要验证**: bob的callback handler是否错误地使用了Data匹配而不是Tag匹配？

### 发现 #7: 真正的问题 - X-ResponseAction被过滤！💡💡💡
**时间**: 2025-01-10
**用户澄清**: 
- ✅ Action tag **不会**被过滤
- ❌ **自定义的X-ResponseAction tag被过滤**
- 问题：原始SAGA实现依赖`X-ResponseAction` tag来传递callback的Action名称

**原始SAGA工作流程**（修改前）:
1. bob发送GetInventoryItem请求，Tags包含：`X-SagaId`, `X-ResponseAction=GetInventoryItem_Callback`
2. alice收到请求，从Tags提取`X-ResponseAction`
3. alice响应时，将`X-ResponseAction`的值作为response的`Action` tag发送回去
4. bob收到响应，根据`Action` tag匹配callback handler

**为什么失败**:
- AO过滤了自定义tag `X-ResponseAction`
- alice收不到`X-ResponseAction`，无法知道应该设置什么`Action`给响应消息
- bob收到的响应消息没有正确的`Action` tag
- callback handler无法被触发

**解决方案**:
我们的Data嵌入方案是对的！但需要确保：
1. ✅ bob在request Data中嵌入`X-ResponseAction`（已实现）
2. ✅ alice从Data中提取`X-ResponseAction`（已实现）
3. ✅ alice在response时将`X-ResponseAction`作为`Action` tag（已实现）
4. ✅ bob的callback handler使用Tag匹配而不是Data匹配（已修复）

### 发现 #8: Bug修复！🎉
**时间**: 2025-01-10
**Bug**: 所有SAGA callback handlers错误地使用了`messaging.hasMatchingDataAction`
**修复**: 改为使用`Handlers.utils.hasMatchingTag("Action", ...)`
**原因**: 
- `Action` tag不会被过滤
- `messaging.respond`已经正确地将`X-ResponseAction`从Data中提取并设置为`Action` tag
- callback handler应该匹配`Action` tag而不是从Data中提取

**修复的文件**:
- `src/a_ao_demo.lua`: 将5个callback handlers改为使用Tag匹配
- `src/messaging.lua`: 删除了不再需要的`messaging.hasMatchingDataAction`函数

## 🔬 下一步调试计划

### Plan A: 检查bob是否发送了GetInventoryItem请求 ✅ 进行中
- [x] 添加DEBUG_LOG
- [ ] 在SAGA起始handler中添加日志，确认是否发送了请求

### Plan B: 检查alice是否收到GetInventoryItem请求
- [ ] 在alice的`get_inventory_item` handler中添加日志
- [ ] 检查alice是否收到消息

### Plan C: 检查alice的响应消息
- [ ] 检查alice的响应是否包含正确的Action
- [ ] 检查响应的Data是否包含Saga信息

## 📝 代码修改记录

### 修改 #1: messaging.hasMatchingDataAction (可能不需要)
**文件**: src/a_ao_demo.lua, src/messaging.lua
**原因**: 误认为Action tag被过滤
**状态**: ⚠️ 可能需要回退

### 修改 #2: Data嵌入Saga信息
**文件**: src/messaging.lua, src/inventory_service.lua
**原因**: 替代Tag传递
**状态**: ✅ 保留（作为增强功能）

## 🎯 测试目标
- [ ] `run-saga-tests.sh` 完全通过
- [ ] alice的库存数量更新为119
- [ ] bob的SAGA实例状态为completed

## 🔥 最新测试结果
**时间**: 2025-01-10
**状态**: ❌ 失败
**SAGA状态**: 卡在步骤2（current_step=2, completed=false）
**库存状态**: 未更新（仍为100）

**问题分析**:
- ❌ **步骤1的callback从未被触发！** （BOB_CALLBACK_LOG为空）
- ❌ bob的Inbox没有alice的响应消息
- ❓ alice是否发送了响应？或者响应的Action tag不正确？

### 发现 #9: 核心问题 - 步骤1的callback未被触发 🔥🔥🔥
**时间**: 2025-01-10  
**关键发现**:
- SAGA推进到步骤2，但这可能是saga.create_saga_instance时默认设置的
- 步骤1的GetInventoryItem_Callback从未执行（callback日志为空）
- bob的Inbox没有来自alice的响应消息
- **可能原因**:
  1. alice的handler没有被触发（没收到请求）
  2. alice的handler执行出错（没发送响应）
  3. alice发送了响应，但Action tag设置不正确，导致没有handler匹配（消息应该在bob的Inbox）

### 发现 #10: 跨进程消息未到达 🔥🔥🔥
**时间**: 2025-01-10
**测试结果**:
- 从bob用`Send()`向alice发送GetInventoryItem请求
- 等待15秒后，bob没有收到任何响应
- bob的Inbox仍然只有初始消息
- bob的callback日志为空

**怀疑**:
1. ❓ `ao.send()`在eval中是否能正常发送跨进程消息？
2. ❓ alice是否真的收到了bob的请求？
3. ❓ alice是否调用了`messaging.respond`？
4. ❓ `ao-cli eval`的输出解析是否有问题（很多eval返回空）？

**下一步**:
- 需要验证跨进程消息传递是否真的工作
- 可能需要用`ao-cli message`而不是`eval`中的`Send()`来触发SAGA

### 发现 #11: 真正的BUG - saga.create_saga_instance不保存data！🔥🔥🔥🔥🔥
**时间**: 2025-01-10
**根本原因找到了！**

**Bug分析**:
```lua
-- src/saga.lua:58-63
saga_instance.participants[#saga_instance.participants + 1] = {
    {
        target = target,
        tags = tags,
        -- ❌ 缺少: data = data
    },
}
```

**问题链条**:
1. `inventory_service.lua:88`创建包含Saga信息的`request`（data）
2. 调用`messaging.commit_send_or_error(status, request_or_error, commit, target, tags)`
3. `request_or_error`（包含Saga信息的data）被传递给`send`函数
4. `send`函数正确地发送了data
5. **但是**`saga.create_saga_instance`创建participant时，根本没有接收和存储data参数！
6. 所以participant中的data是`nil`
7. 虽然第一次消息发送时data是正确的（因为直接传给了send）
8. 但这个设计本身就有问题 - participant应该记录完整的消息信息

**等等！** 如果第一次发送的data是正确的，那alice应该能收到Saga信息并正确响应啊？

**重新分析**：或许问题不在这里？让我检查bob实际发送的消息内容...

### 发现 #12: ao-cli eval中的Send()跨进程消息未到达 🚨🚨🚨
**时间**: 2025-01-10
**测试结果**:
1. 从alice用`Send()`向bob发送消息 → bob没有收到（BOB_MSG_LOG为空）
2. 用`ao-cli message`从外部向bob发送消息 → 测试中（但ao-cli eval输出解析有问题）
3. alice的get_inventory_item handler从未被触发（GET_INV_ITEM_LOG为空）
4. 这意味着bob从未向alice发送GetInventoryItem请求

**核心问题**:
- **`eval`中的`Send()`可能无法发送跨进程消息到另一个长期运行的进程**
- 或者消息发送了但需要更长时间才能到达
- 或者`ao-cli eval`的输出解析有严重问题，导致无法正确查看日志

**ao-cli eval输出问题**:
- 很多eval命令返回空Output
- 即使是简单的`return tostring(#BOB_MSG_LOG)`也返回空
- 这使得调试变得非常困难

**下一步**:
需要用户确认或尝试其他调试方法（如aos CLI，虽然用户不推荐）

## 🚨 核心发现：SAGA卡在步骤2的真相

**时间**: 2025-01-10
**状态**: 🔴 严重问题

### 关键证据链：

1. **SAGA状态**: current_step=2, completed=false
2. **Step 1 callback**: 已执行4次 (DEBUG_GET_INVENTORY_ITEM_CALLBACK_COUNT=4)
3. **Step 2请求**: alice收到0次 (DEBUG_CREATE_SINGLE_LINE_IN_OUT_COUNT=0)
4. **Bob Inbox**: 有alice的CreateSingleLineInOut响应，但**没有Action tag**！

### 问题定位：

#### 发现 #13: Alice的响应消息缺少Action tag 🔥🔥🔥
**证据**: Bob Inbox最后一条消息：
```json
{
  "From": "alice进程ID",
  "Data": "{\"result\":{\"version\":0,\"in_out_id\":1}}",
  "Tags": {
    // ❌ 没有Action tag！
  }
}
```

#### 发现 #14: messaging.respond提取的response_action是正确的 ✅
**证据**: `DEBUG_MESSAGING_RESPOND_CALLS`显示：
```
response_action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback"
```

#### 发现 #15: 响应Data中也没有Saga信息 ❌
**证据**: Bob Inbox消息的Data中没有`X-SagaId`

### 根本原因推测：

**`messaging.respond`的逻辑有bug！**

虽然`messaging.extract_saga_info_from_data`提取到了正确的`response_action`，但：
1. `message.Tags`没有被正确设置（或被AO过滤）
2. 响应Data中没有嵌入Saga信息

**需要检查的代码路径**:
```lua
-- messaging.respond中
if response_action then
    message.Tags = { Action = response_action }  -- ❓ 这里设置了，为什么bob收不到？
end

if saga_id then
    data = messaging.embed_saga_info_in_data(data, saga_id, response_action)
    message.Data = json.encode(data)  -- ❓ 这里重新编码了，但为什么bob收到的Data中没有Saga信息？
end
```

### 下一步调试计划：

1. ✅ 验证：`messaging.respond`是否被调用
2. ✅ 验证：`response_action`是否正确提取
3. ⏳ **验证**：`messaging.respond`中`ao.send(message)`发送的消息是否包含正确的Tags和Data
4. ⏳ **验证**：Bob收到的消息与alice发送的消息是否一致

## 💡 重要洞察

### 洞察 #1: 不要过早下结论
之前认为Action被过滤是错误的。需要通过实际测试验证每一个假设。

### 洞察 #2: SAGA逻辑是工作的
步骤1成功完成证明了SAGA核心逻辑、消息传递机制、Action匹配都是可以工作的。

### 洞察 #3: 问题可能很简单
可能不需要`messaging.hasMatchingDataAction`这样的复杂修改。问题可能只是某个小bug。

### 洞察 #4: messaging.respond的Data处理有bug
`messaging.respond`中先将data编码为JSON，然后又尝试修改data并重新编码，这个流程有问题！

## 🎉 最终解决方案与核心经验教训

**时间**: 2025-01-10
**状态**: ✅ 完全解决

### 🔥 核心Bug定位

**问题根源**：`messaging.respond`函数中的逻辑错误

```lua
-- ❌ 错误的实现
if saga_id then
    data = messaging.embed_saga_info_in_data(data, saga_id, response_action)  -- 错误！
    message.Data = json.encode(data)
end
```

**问题分析**：
1. `response_action`是从**请求消息**中提取的，表示"收到响应时应该触发的callback action"
2. 这个值已经正确设置在响应消息的`Tags.Action`中用于触发callback handler
3. **不应该**再次将它嵌入到响应Data中
4. 响应Data中只需要嵌入`saga_id`，callback handler只需要识别SAGA实例

### ✅ 正确的实现

```lua
-- ✅ 正确的实现
if saga_id then
    data = messaging.embed_saga_info_in_data(data, saga_id, nil)  -- 只嵌入saga_id
    message.Data = json.encode(data)
end
```

### 📚 核心经验教训

#### 教训 #1: 区分请求和响应的Saga信息
- **请求消息**需要嵌入：`saga_id` + `response_action`（告诉对方收到响应后调用哪个callback）
- **响应消息**只需嵌入：`saga_id`（让callback识别SAGA实例）
- **响应消息**的`Tags.Action`应该设置为**请求消息**中的`response_action`

#### 教训 #2: Data嵌入是绕过AO Tag过滤的唯一可靠方案
- ✅ **Action tag不会被过滤**：可以用于handler匹配
- ❌ **自定义tag会被过滤**：`X-SagaId`、`X-ResponseAction`等跨进程传递时丢失
- ✅ **Data字段完全可靠**：不受AO系统的Tag过滤影响
- ✅ **混合策略最优**：Action用Tag，Saga信息用Data

#### 教训 #3: 理解AO的消息传递机制
- **`Action` tag**：系统标准tag，用于handler匹配，不会被过滤
- **自定义tag**：会被AO的`nonForwardableTags`机制过滤
- **Data字段**：业务数据载体，系统不解析不过滤
- **跨进程通信**：必须使用Data嵌入传递自定义协调信息

#### 教训 #4: 调试分布式系统的方法论
1. ✅ **添加全局调试变量**：记录关键函数的调用和参数
2. ✅ **验证消息收发**：检查发送方和接收方的实际消息内容
3. ✅ **逐步验证假设**：不要过早下结论，用实际测试验证每个假设
4. ✅ **关注数据流**：追踪数据在整个流程中的变化

#### 教训 #5: 不要混淆请求和响应的数据结构
- **发送请求时**：嵌入`response_action`告诉对方"收到响应后调用哪个callback"
- **发送响应时**：**不应该**再嵌入`response_action`
- **发送响应时**：应该将请求中的`response_action`设置为响应的`Tags.Action`

### 🎯 验证结果

修复后的测试结果：
- ✅ **SAGA完全成功**：current_step=6, completed=true
- ✅ **库存正确更新**：从100更新到119
- ✅ **测试完全通过**：`run-saga-tests.sh`所有6个步骤成功
- ✅ **跨进程通信正常**：alice↔bob消息传递无误

### 📝 修改总结

**核心修改**：
```lua
// src/messaging.lua:114-119
if saga_id then
    data = messaging.embed_saga_info_in_data(data, saga_id, nil)  // 只传递saga_id
    message.Data = json.encode(data)
end
```

**影响的文件**：
- `src/messaging.lua`: 修复`respond`函数
- `ao-cli-non-repl/tests/run-saga-tests.sh`: 修复库存验证逻辑
- 移除所有调试代码

### 🚀 长期价值

这次修复为AO平台上的分布式事务实现提供了关键洞察：
1. **Data嵌入策略**是绕过Tag过滤的标准方案
2. **明确区分请求和响应**的Saga信息传递模式
3. **混合使用Tag和Data**：Action用Tag，Saga协调信息用Data
4. **可作为DDDML工具**的代码生成模板参考

---

**最后更新**: 2025-01-10
**当前状态**: ✅ 完全解决 - SAGA跨进程执行成功

