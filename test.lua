local elem = get_element_by_id("button")

elem:on("hover_enter", function()
  print("hovered over")
end)


elem:on("hover_leave", function()
  print("not hovered")
end)


elem:on("click", function()
  print("click")
end)