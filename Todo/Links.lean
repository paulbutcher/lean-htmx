import Routing.RouteTable

routeTable! Todo
  [ "/"                      as index,
    "/active"                as active,
    "/completed"             as completed,
    "/todos"                 as todos,
    "/todos/:id:Nat"         as todo,
    "/todos/:id:Nat/edit"    as edit,
    "/todos/:id:Nat/toggle"  as toggle,
    "/todos/toggle-all"      as toggleAll,
    "/todos/clear-completed" as clearCompleted ]
