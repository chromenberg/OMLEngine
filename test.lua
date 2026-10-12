local elem = get_element_by_id("button")
local hovered = false
local function reset_color()
	set_color(elem, "#26282c")
end

elem:on("mouse:over.enter", function()
	hovered = true
	set_color(elem, "#36363a")
end)


elem:on("mouse:over.leave", function()
	hovered = false
	reset_color()
end)

elem:on("mouse:down", function()
	set_color(elem, "#3f3f42")
	
end)

elem:on("mouse:up", function()
	if hovered then
		set_color(elem, "#36363a")
		
	else
		reset_color()
	end
end)

