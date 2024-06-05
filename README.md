# An AO Dapp Development Demo with a Low-Code Approach

English | [中文版](./README_CN.md)


AO is on the right path of development.

We believe that the major obstacle to the widespread adoption of Web3 is the engineering complexity involved in building large-scale decentralized applications (DApps).
This complexity hinders our ability to develop more diverse, larger-scale, and feature-rich decentralized applications under the constraints of limited resources—a common scenario in the early stages of development.

> Do not be swayed by claims like "Smart contracts/on-chain programs should be simple and not overly complex." Such statements often misrepresent the engineering reality.

Compared to Web2, Web3 still has significant room for improvement in terms of technical infrastructure, tools, and practical experience.
AO has filled a significant gap in this area. At the very least, AO, as the best decentralized *message broker*[^MsgBrokerWp] in the current Web3 domain, has shown tremendous potential.

> Developers familiar with traditional Web2 applications might consider Kafka for comparison: can you imagine how large-scale internet applications would be written without Kafka or Kafka-like message brokers?

For instance, traditional large and complex applications rely on messaging mechanisms to achieve decoupling between components, which is crucial for enhancing system maintainability and scalability.

Moreover, these applications often adopt an "eventual consistency" model when necessary to further improve system availability and scalability.

However, even in the more mature engineering environment of Web2, achieving "eventual consistency" through message communication remains a challenge for many developers.

> Developing DApps on the nascent AO platform seems to accentuate this challenge even more :-).

For example, consider the following Lua code (for AO DApp) — does it seem "natural" to write it this way?

```lua
Handlers.add(
    "a_multi_step_operation",
    Handlers.utils.hasMatchingTag("Action", "AMultiStepOperation"),
    function(msg)
        local status, result_or_error = pcall((function()
            local foo = do_a_mutate_memory_state_operation()
            local bar = do_another_mutate_memory_state_operation()
            return { foo = foo, bar = bar }
        end))
        ao.send({
            Target = msg.From,
            Data = json.encode(
                status and { result = result_or_error } 
                or { error = tostring(result_or_error) }
            )
        })
    end
)
```


If you're not familiar with Lua, think of the `pcall` function as being similar to the try-catch constructs of other languages: 
it tries to execute a function, returning `true` and the result of the function if it succeeds, and `false` and an error object if it fails.

Do you see the problem? Suppose the step `do_a_mutate_memory_state_operation` step succeeds and the step `do_another_mutate_memory_state_operation` fails.
The recipient (`Target`) of the message receives an `error` message. 
Common sense would dictate that the receiver can safely assume that the operation failed, but that nothing has changed and everything is fine.
However, in reality, the `do_a_mutate_memory_state_operation` step has already succeeded and the state of the system has changed! 
In other words, the information conveyed by the message is **inconsistent** with the actual state of the system.

In traditional Web2 development environments, we can usually solve this problem by using the *transactional outbox pattern*[^TransactionalOutbox].
But on the AO platform, where we don't have the database ACID transactions available that the transactional outbox pattern relies on, 
things get a little tricky.

Fortunately, by using the dddappp low-code tool, we can greatly simplify the complexity of AO dapp development.
In the next demo, we'll show how dddappp can be used to elegantly solve these problems and strongly support our point.


## Background Knowledge

We feel it may be necessary to start with some background knowledge so that you can better understand the content of this demo. 
If you're already familiar with the content, you can skip ahead to the [next section](#Prerequisites).
We will occasionally use some DDD (Domain Driven Design) terminology in the following lines, but we believe that even if you are not familiar with DDD, it should not affect your overall understanding.


### About "eventual consistency"

An application that needs to be launched quickly often begins with the use of a total "strong consistency" architecture 
(Indeed, using "eventual consistency" instead of "strong consistency" can lead to higher application development costs). 
But if the app becomes popular, as the user base grows and all available options for vertical scaling 
(e.g. better and more expensive hardware) are exhausted, 
it eventually becomes necessary for the application to improve its software architecture - including the use of "eventual consistency".


### What is the trouble without having ACID database transactions?

For example, let's say that in the domain model of a WMS application, 
the `InventoryItem` entity (in DDD terms, this is an "aggregate root") represents "the quantity of a product in stock at a particular location".
If we intend to implement an Inventory Movement service using the eventual consistency model, 
we need to take into account the scenarios that may occur when executing this movement service:

- Product A was originally in stock at the source location in quantities of 1,000 units.
- We start an operation to move 100 units of Product A to the target location.
- Initially, our inventory movement service deducts the inventory quantity at the source location, and the quantity of Product A in stock at that location becomes 900-a result that is persistent and cannot be "rolled back" through a database transaction, but the inventory quantity at the target location has not yet been increased, and the movement has not yet been finalized.
- Then, someone else uses up (ships out) 100 units of Product A in the source location for manufacturing purposes, and the quantity on hand becomes 800 - this result is also persistent and cannot be rolled back using a database transaction.
- Then, for some reason, we can't increase the quantity of Product A in the target bay, so we need to cancel the transfer.
- At this point, we should change the quantity of Product A in stock at the source location to 900 (this known as a "**compensate**" operation), which means that we add back 100 units to the quantity of 800, rather than changing the quantity back to the quantity (1000 units) that was in stock before the movement operation.

> Although in the above scenario we are only changing the state of two entity "instances" of the `InventoryItem`, 
> and no more "entities" (types) are involved, it is still the practice of the DDD community to recommend that developers consider 
> (at least "think about it") using a "eventual consistency" model to implement such business logic.


Not to mention that in such a domain model, there might be another `MovementOrder` entity (aggregate root), 
which would make the "eventual consistency" implementation of the entire movement business logic even more complex.


### Implementing Eventual Consistency with Saga

If we intend to use the "eventual consistency" model to achieve consistency of state (data) across multiple aggregates, 
we need to consider using the *Saga pattern*[^SagaPattern].

What is this Saga thing? Let's see what ChatGPT has to say about it:

> SAGA is a design pattern called Saga Pattern for Distributed Transactions. It is a solution for executing long-running transactions in a distributed system, ensuring both data consistency and reliability.
> 
> In Saga Pattern, a long-running transaction is decomposed into multiple steps, each of which is an atomic operation and corresponds to a transaction. Whenever a step completes, Saga emits an event that triggers the execution of the next step. If a step fails, Saga performs a compensating action to undo the completed step, thus ensuring data consistency.
> 
> In short, the SAGA pattern solves the problem of long-running transactions in a distributed system by splitting a large transaction into small atomic operations, and ensuring data consistency and reliability by passing events between each step and performing compensating actions.

It is obvious that Saga implements business transactions using a eventual consistency model. 
Ensuring the eventual consistency of data is the business logic that the application developer is **responsible** for implementing.

### Two Styles of Saga

There are two styles of Saga: *Choreography-based Saga* and *Orchestration-based Saga*.

Choreography-based Saga does **not** have a central coordinator. 
Instead, everyone advances the business process by publicly publishing messages/events. 

For example:

* When a customer places an order, the *order service* publishes an `OrderPlaced` event — it doesn't particularly care who is interested in this event. 
  The act of publishing the event is akin to yelling:
    > Someone has placed an order!
    >
* Perhaps the *inventory service* is interested in this event and "subscribes" to it. 
  Upon receiving the event, it may reserve inventory according to the product and quantity information of the order, 
  preparing for the subsequent shipping operation. 
  Similarly, after reserving the inventory, it publishes an `InventoryReserved` event — akin to yelling:
    > Inventory has been reserved!
    >
* Maybe the *picking service* has been listening for such messages because after the inventory is reserved, it's time for the pickers to get to work...


In the execution process of the business flow described above, there is **no** coordinator responsible for:

* Commanding what each service should do;
* Recording the results of each service's actions;
* Deciding which service should continue after one completes its task, or what to do if a service completely fails to proceed.


On the other hand, the Orchestration-based Saga [**does**] have a central commander, known as the *Saga Manager*.
The interaction between the Saga Manager and services (components) may use asynchronous message-based communication mechanisms or synchronous RPC methods.


### Event Driven Architecture (EDA) and Saga

Choreography-based Saga can be thought of as very close to what EDA is supposed to be.

In general, events are published, usually using *asynchronous messaging* mechanisms (of course, more seriously, synchronous RPCs is not out of the question).

Orchestration-based Saga can use either asynchronous messaging or RPCs, 
but obviously the former is generally more lightweight.
In fact, on top of asynchronous messaging, we can also wrap up APIs for synchronous-calls.

Specifically, a call named `Xxx` can be decomposed into the process of publishing a pair of events: `XxxRequested` / `XxxResponded`.
The caller publishes the former and the callee publishes the latter.

Since Orchestration-based Saga's calls to services (components) can be broken down into events, 
it is not wrong to say that it is a special form of EDA.


---

In general, asynchronous messaging is used extensively within EDA.
Asynchronous messaging mechanisms typically make use of *Message Broker* [^MsgBrokerWp].
(You may notice that in many cases, we do not strictly distinguish between the concepts of *events* and *messages* in our text.)


### How to design a Orchestration-based Saga

Implementing a Saga can be tricky. Choreography-based Saga is more troublesome than Orchestration-based Saga to implement complex features. 
Therefore, it is necessary to consider using DSL to help implement a Orchestration-based Saga.

Here is an example of how to orchestrate a Saga.

Let's say we are developing a WMS application and we have defined two aggregates, `InventoryItem` and `InOut`, in our domain model.

Now, we desire a domain service that "forcefully" modifies the "in-stock quantity" of inventory items. 
This service might have a method named `CreateOrUpdateInventoryItem`.
We might use this service method after conducting a physical inventory count for "inventory surplus/shortage" adjustments.
Although we are directly modifying the in-stock quantity of inventory items at this time, 
we still wish to use `InOut` (Inbound/Outbound Order) to record the changes in inventory quantity, 
so this method will involve two aggregates.

Assuming we deploy these two aggregates as two microservices, 
we need to use an "eventual consistency" strategy to implement this "business transaction" that modifies the in-stock quantity.

First, we design the various implementation steps of this business transaction, roughly as follows:

1. Query the information of the inventory item (`InventoryItem`).
   Based on the results of the query, we determine whether it is necessary to create a new inventory item record or update an existing one, and what the `MovementQuantity` of the Inbound/Outbound Order line item should be.
2. Create an Inbound/Outbound Order (`InOut`).
   This document has only one line (`InOutLine`), and the `MovementQuantity` of the line item is the difference between the updated in-stock quantity and the current in-stock quantity (the quantity we saw in the previous step).
3. Add an inventory item entry (`InventoryItemEntry`). 
   Our inventory item aggregate should have adopted the accounting pattern, so we need to indirectly update the in-stock quantity of inventory items in this way.
4. If the update of the inventory item is successful, then update the status of the Inbound/Outbound Order to "Completed".
5. If the update of the inventory item fails, then update the Inbound/Outbound Order to "Cancelled" — this operation is the **compensation** for the second step.

We can notice that, compared to the simple use of database local transactions to ensure strong consistency, here we have significantly added the fourth and fifth coding tasks.

Having conceptualized our approach, we now need to define the corresponding methods for the steps mentioned above.

Several methods are required for operating the `InventoryItem` aggregate:

* `GetInventoryItem`, a method for retrieving the state of an inventory item through its aggregate root ID (the ID of the inventory item).
* `AddInventoryItemEntry`, a method for adding an inventory item entry, which is the sole way (indirectly) to modify those quantity properties (accounts) of the inventory item.

Additionally, we need to write three methods for operating the `InOut` aggregate:

* CreateSingleLineInOut, a method for creating an In/Out document, which contains only one line (`InOutLine`).
* `Complete`, a method for updating the status of the In/Out document to "Completed".
* `Void`, a method for updating the In/Out document to "Cancelled".

These methods serve as the building blocks for implementing a Orchestration-based Saga.

With these foundational components in place, we can finally write the orchestration logic of the Saga on top of them to implement the service `CreateOrUpdateInventoryItem`.

It's evident that without a DSL, the process of implementing an Orchestration-based Saga is quite cumbersome — undoubtedly, 
using a Choreography-based Saga to achieve the same business logic would only be more so. 😂

So, what would a DSL designed for this purpose look like?

Don't worry, we will soon demonstrate how to develop an AO Dapp using the dddappp low-code tool.
This application will, of course, include the Saga implementation for the `CreateOrUpdateInventoryItem` service discussed above.
However, if you're eager for a sneak peek, you can directly check out our [DDDML model file](./dddml/a-ao-demo.yaml),
where the definition of the `ProcessInventorySurplusOrShortage` method of the `InventoryService` service is provided.


## Prerequisites

If you want to follow us through the process of the demo, install the tools below:

* Install [aos](https://cookbook_ao.g8way.io/welcome/getting-started.html)
* Install [Docker](https://docs.docker.com/engine/install/).



Then, start an aos process now:


```shell
aos process_alice
```

Let's take note of its process ID, e.g. `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`.
We use the placeholder `__PROGRESS_ALICE__` for it in some following example commands.


## Programming

### Write DDDML Model

The model file that has been written is available at `./dddml/a-ao-demo.yaml`.

For developers with some experience in OOP (Object-Oriented Programming), what the model expresses should not be difficult to understand.

Let's catch the main thread first. We mainly define two aggregates in the model: `Article` and `InventoryItem`, and the service `InventoryService`.
And the service `InventoryService` depends on two components: the `InventoryItem` aggregate and an abstract `InOutService` service - you can think of "abstract" here as meaning that we describe what the service "should look like", 
but we don't intend to implement it ourselves, expecting "others" to implement it.

> **Tip**
>
> About DDDML, here is an introductory article: ["Introducing DDDML: The Key to Low-Code Development for Decentralized Applications"](https://github.com/wubuku/Dapp-LCDP-Demo/blob/main/IntroducingDDDML.md).


### Generate Code

In repository root directory, run:

```shell
docker run \
-v .:/myapp \
wubuku/dddappp-ao:0.0.1 \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```

The command parameters above are straightforward:

* This line `-v .:/myapp \` indicates mounting the local current directory into the `/myapp` directory inside the container.
* `dddmlDirectoryPath` is the directory where the DDDML model files are located. It should be a directory path that can be read in the container.
* Understand the value of the `boundedContextName` parameter as the name of the application you want to develop. When the name has multiple parts, separate them with dots and use the PascalCase naming convention for each part. 
    Bounded-context is a term in Domain-driven design (DDD) that refers to a specific problem domain scope that contains specific business boundaries, constraints, and language. 
    If you cannot understand this concept for the time being, it is not a big deal.
* `aoLuaProjectDirectoryPath` is the directory path where the "on-chain contract" code is placed. It should be a readable and writable directory path in the container.


#### Update dddappp Docker Image

Since the dddappp v0.0.1 image is updated frequently, 
if you've run the above command before and run into problems, 
you may be required to manually delete the image and pull it again before `docker run`.

```shell
# If you have already run it, you may need to Clean Up Exited Docker Containers first
docker rm $(docker ps -aq --filter "ancestor=wubuku/dddappp-ao:0.0.1")
# remove the image
docker image rm wubuku/dddappp-ao:0.0.1
# pull the image
docker pull wubuku/dddappp-ao:0.0.1
```

### Filling in the business logic

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

#### Modify `inventory_item_add_inventory_item_entry_logic`

Modify the file `./src/inventory_item_add_inventory_item_entry_logic.lua` to fill the function body with business logic:

```lua
function inventory_item_add_inventory_item_entry_logic.verify(_state, inventory_item_id, movement_quantity, cmd, msg, env)
    return inventory_item.new_inventory_item_entry_added(inventory_item_id, _state, movement_quantity)
end

function inventory_item_add_inventory_item_entry_logic.mutate(state, event, msg, env)
    if (not state) then
        state = inventory_item.new(event.inventory_item_id, event.movement_quantity)
    else
        state.quantity = (state.quantity or 0) + event.movement_quantity
    end
    if (not state.entries) then
        state.entries = {}
    end
    local entry = {
        movement_quantity = event.movement_quantity,
    }
    state.entries[#state.entries + 1] = entry
    return state
end
```

#### Modify `inventory_service_local`

Modify the file `./src/inventory_service_local.lua` to fill the function body with business logic:

```lua
function inventory_service_local.process_inventory_surplus_or_shortage_prepare_get_inventory_item_request(context)
    local _inventory_item_id = {
        product_id = context.product_id,
        location = context.location,
    }
    context.inventory_item_id = _inventory_item_id
    return _inventory_item_id
end

function inventory_service_local.process_inventory_surplus_or_shortage_on_get_inventory_item_reply(context, result)
    context.item_version = result.version -- NOTE: The name of the field IS "version"!
    local on_hand_quantity = result.quantity
    local adjusted_quantity = context.quantity

if (adjusted_quantity == on_hand_quantity) then -- NOTE: short-circuit if no changed
        local short_circuited = true
        local is_error = false
        -- If the original request requires a result, provide one here if a short circuit occurs.
        local result_or_error = "adjusted_quantity == on_hand_quantity"
        return short_circuited, is_error, result_or_error
    end

    local movement_quantity = adjusted_quantity > on_hand_quantity and
        adjusted_quantity - on_hand_quantity or
        on_hand_quantity - adjusted_quantity
    context.movement_quantity = movement_quantity
end
```

#### Modify `in_out_service_mock`


As mentioned above, we declare `InOutService` as `abstract` in our model, 
indicating that we don't intend to implement it ourselves, but expect others to do so.
So here we use `in_out_service_mock.lua` to mock the behavior of `InOutService` for testing purposes.

Modify the file `. /src/in_out_service_mock.lua`:

```lua
Handlers.add(
    "create_single_line_in_out",
    Handlers.utils.hasMatchingTag("Action", "CreateSingleLineInOut"),
    function(msg, env, response)
        messaging.respond(true, {
            in_out_id = 1,
            version = 0,
        }, msg)
        -- messaging.respond(false, "TEST_CREATE_SINGLE_LINE_IN_OUT_ERROR", msg) -- error
    end
)
```

#### Modify `inventory_service_config`

Modify the "configuration file" `./src/inventory_service_config.lua` and fill in the `__PROGRESS_ALICE__` recorded above:

```lua
return {
    inventory_item = {
        get_target = function()
            return "DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q" -- <- Fill in the __PROGRESS_ALICE__
        end,
        -- ...
    },
    in_out = {
        get_target = function()
            return "DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q" -- <- Fill in the __PROGRESS_ALICE__
        end,
        -- ...
    }
}
```


## Testing the Application


Start another aos process:

```shell
aos process_bob
```

Record its process ID, such as `u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4`.
We might use the placeholder `__PROGRESS_BOB__` for it in some following example commands.

In this aos (`__PROGRESS_BOB__`) process, load our application code (be wary of replacing `{PATH/TO/A-AO-Demo/src}` with the actual path):

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

It is now ready to be tested in the first process (`__PROGRESS_ALICE__`) by sending messages to this `__PROGRESS_BOB__` process.


### "Article" aggregate tests

In the first process (`__PROGRESS_ALICE__`), check the current "article Id sequence" in the other process:

```lua
json = require("json")
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticleIdSequence" } })
```

You'll get a response like this:

```text
New Message From u37...zs4: Data = {"result":[0]}
```

Create a new article:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "CreateArticle" }, Data = json.encode({ title = "title_1", body = "body_1" }) })
```

After receiving a response, check the content of the last message in the inbox:

```lua
Inbox[#Inbox]
```

Check current article Id sequence again:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticleIdSequence" } })
```

View the contents of the article with ID `1` (in the `Data` property of the output message):

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticle" }, Data = json.encode(1) })
Inbox[#Inbox]
```

Update the body of the article with ID `1` (note that the value of `version` should match the version of the article seen above):

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "UpdateArticleBody" }, Data = json.encode({ article_id = 1, version = 0, body = "new_body_1" }) })
```

View the contents of the article with ID `1` again:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticle" }, Data = json.encode(1) })
Inbox[#Inbox]
```

### "Inventory Item" aggregate tests


Send the following messages in the process `__PROGRESS_ALICE__`, 
which trigger the execution of the `AddInventoryItemEntry` action in the `__PROGRESS_BOB__` process to update the inventory items:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 100}) })

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 130, version = 0}) })

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 100}) })

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 101, version = 0}) })
```

View the state of the inventory items:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })

Inbox[#Inbox]

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }) })

Inbox[#Inbox]
```


### Manually Sending Messages to Test Saga

First, we'll manually send messages to step by step test and observe the execution process of the Saga.

In the `__PROGRESS_ALICE__` process, we check the current Saga instance Id sequence in another process `__PROGRESS_BOB__`:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaIdSequence" } })
-- New Message From u37...zs4: Data = {"result":[0]}
```

Execute the following command to kick off the `InventoryService.ProcessInventorySurplusOrShortage` method:


```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })
```

This creates a new Saga instance. Obviously, the first Saga instance created should have the Id of `1`.

View the state of the Saga instance with Id `__SAGA_ID__`:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

Query the version of the inventory item:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })

Inbox[#Inbox]
```

Send a message to advance the Saga instance to the next step (note to replace the placeholder `__ITEM_VERSION__` with the version of the inventory item queried above, and replace the placeholder `__SAGA_ID__` with the Id of the Saga instance created above):

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = { product_id = 1, location = "x", version = __ITEM_VERSION__, quantity = 110 } }) })
```

Check if the state of the Saga with Id `__SAGA_ID__` has been updated:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })
-- Inbox[#Inbox]
```

Continue to send mock messages to advance the Saga instance (note to replace the placeholder `__SAGA_ID__` with actual value):

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = { in_out_id = 1, version = 0 } }) })
```

Continue to send mock messages to advance the Saga instance:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = {} }) })
```

Continue to send mock messages to advance the Saga instance:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = {} }) })
```

Query the state of the Saga instance with Id `__SAGA_ID__`:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

You should see the code snippet `"completed":true` in the `Data` property value of the printed content,
indicating that the execution status of this Saga instance is "completed".


### Testing Cross-Process Execution of Saga

When modifying `./src/inventory_service_config.lua` earlier,
we directed the `target` of the two components `inventory_item` and `in_out`, which the "Inventory Service" depends on, 
to the `__PROGRESS_ALICE__` process.

Let's first load the `inventory_item` component in the `__PROGRESS_ALICE__` process
(note that although we loaded the same code as the `__PROGRESS_BOB__` process, 
the subsequent tests only used the parts related to the `InventoryItem` aggregate):

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

Next, also in the `__PROGRESS_ALICE__` process, load the mock `InOutService` component:

```lua
.load {PATH/TO/A-AO-Demo/src}/in_out_service_mock.lua
```

在 `__PROGRESS_ALICE__` 进程中，查看另外一个进程 `__PROGRESS_BOB__` 中的当前 Saga 实例的序号：

In the `__PROGRESS_ALICE__` process, check the current Saga instance Id sequence in another `__PROGRESS_BOB__` process:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaIdSequence" } })
```

In the `__PROGRESS_ALICE__` process, "create a new inventory item" for itself
(note to replace the placeholder `__PROGRESS_ALICE__` with the actual process ID, such as `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`):

```lua
Send({ Target = "__PROGRESS_ALICE__", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "y" }, movement_quantity = 100}) })
```

Execute the following command to kick off the `InventoryService.ProcessInventorySurplusOrShortage` method in the `__PROGRESS_BOB__` process:


```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "y", quantity = 119 }) })
-- New Message From u37...zs4: Data = {"result":{"in_out_i...
```

View the state of the inventory items in the `__PROGRESS_ALICE__` process:


```lua
Send({ Target = "__PROGRESS_ALICE__", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "y" }) })

Inbox[#Inbox]
```

You should see that the quantity of the inventory item has been updated: `Data = "{"result":{"quantity":119,"version":1...`.

Again, check the current Saga instance Id sequence in the `__PROGRESS_BOB__` process:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaIdSequence" } })
```

You should see that the number has increased.

Replace the placeholder `__SAGA_ID__` in the command below with the Id (number) of the latest Saga instance to view the execution process of the Saga instance:

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

If nothing is wrong, the execution status of the Saga instance should be "Completed".


---

[^SagaPattern]: [Microservices.io](http://microservices.io/). Pattern: Saga. [https://microservices.io/patterns/data/saga.html](https://microservices.io/patterns/data/saga.html)

[^TransactionalOutbox]: [Microservices.io](http://microservices.io/). Pattern: Transactional Outbox. [https://microservices.io/patterns/data/transactional-outbox.html](https://microservices.io/patterns/data/transactional-outbox.html)

[^MsgBrokerWp]: [Wikipedia.org](http://wikipedia.org/). Message broker. [https://en.wikipedia.org/wiki/Message_broker](https://en.wikipedia.org/wiki/Message_broker)

