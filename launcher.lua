local background = "#120b1b"
local background_inner = "#08050e"
local search = "#0b0b12"
local friends = "#26263a"
local border = "#24242f"
local friends_border = "#33334a"
local muted = "#9a9aab"
local active =  "#a855f7"


local elems = get_elements_by_class("sidebarItem")
-- local elem = get_element_by_id("root")


local function reset_sidebar_items()
  for _, node in pairs(elems) do
    node["active"] = false
    set_color(node, background)
  end
end

for _, node in pairs(elems) do
  node["active"] = false
  node:on("mouse:hover.enter", function()
    if node["active"] == false then
      set_color(node, friends)
    end
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
