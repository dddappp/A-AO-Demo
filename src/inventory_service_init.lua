-- inventory_service.init(--saga,
return {
    inventory_item = {
        get_target = function()
            return "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4"
        end,
        get_get_inventory_item_action = function()
            return "GetInventoryItem"
        end
    },
    in_out = {
        get_target = function()
            return "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4"
        end,
        get_create_single_line_in_out_action = function()
            return "CreateSingleLineInOut"
        end
    } -- todo
}
