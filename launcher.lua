local background = "#120b1b"
local background_inner = "#08050e"
local search = "#0b0b12"
local friends = "#26263a"
local friends1 = "#36364a"
local border = "#24242f"
local friends_border = "#33334a"
local muted = "#9a9aab"
local active =  "#a855f7"


local elems = get_elements_by_class("sidebarItem")
-- local elem = get_element_by_id("root")

local function cursor_pointer()
  set_cursor_look("pointer")
end

local function cursor_default()
  set_cursor_look("default")
end

local function reset_sidebar_items()
  for _, node in pairs(elems) do
    node["active"] = false
    set_color(node, background)
  end
end

elems[1]["active"] = true
set_color(elems[1], active)

for _, node in pairs(elems) do
  -- Assigning a value to an OML DOM node
  node["active"] = false


  -- Listening to an event from an OML node
  node:on("mouse:hover.enter", function()
    -- uses the current node and checks if the value "active" that was assigned to it is false
    if node["active"] == false then
      -- Updates the color of the node
      set_color(node, friends)
    end

    -- Changes the cursor appearance
    set_cursor_look("pointer")
  end)

  node:on("mouse:hover.leave", function()
    if node["active"] == false then
      set_color(node, background)
    end
    set_cursor_look("default")
  end)

  node:on("mouse:down", function()
    reset_sidebar_items()
    set_color(node, active)
    node["active"] = true
  end)
end


-- Gets every element that has the class ".gameContainer"
-- Returns a table of node references that you can iterate over
local gameCards = get_elements_by_class("gameContainer") 

for _, game in pairs(gameCards) do
    -- listens for when the mouse goes over this node
    game:on("mouse:hover.enter", function()
        cursor_pointer()
        -- Child node modification
        set_color(game.children[1], friends1)
    end)

    -- listens for when the mouse leaves this node
    game:on("mouse:hover.leave", function()
        cursor_default() -- set cursor appearance to default
        set_color(game.children[1], friends)
    end)
end

