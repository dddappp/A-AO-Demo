# README



```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetArticle" }, Data = json.encode(1) })
```


```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetArticleIdSequence" } })
```



```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "CreateArticle" }, Data = json.encode({ title = "title_1", body = "body_1" }) })
```


```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "UpdateArticleBody" }, Data = json.encode({ article_id = 1, version = 3, body = "new_body_1" }) })
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "UpdateArticleBody", ["X-NoResponseRequired"] = "true" }, Data = json.encode({ article_id = 1, version = 8,  body = "new_body_u" }) })
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "UpdateArticleBody", ["X-NoResponseRequired"] = "false", ["X-SagaId"] = "TEST_SAGA_ID" }, Data = json.encode({ article_id = 1, version = 13,  body = "new_body_13" }) })
```


---

```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }) })

Send({ Target = "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })
```



```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 100, version = 0}) })
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 100, version = 0}) })

Send({ Target = "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 130, version = 0}) })
```

---


```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = 1 }) })
```


```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetSagaIdSequence" } })
```


---

请求 `InventoryService` 的 `ProcessInventorySurplusOrShortage` 方法：


```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })
```

```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = { product_id = 1, location = "x", version = 11, quantity = 110 } }) })
```

```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = { in_out_id = 1, version = 0 } }) })
```

```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = {} }) })
```

```lua
Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = {} }) })
```
