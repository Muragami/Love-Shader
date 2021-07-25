--[[
Simple UI: buttons, text entry, message line, button lines (menus)
Jason A. Petrasko 2021
]]

-- make sure we have a class commons implementation!
if (class == nil) then
	class_commons = true
	class = require 'class'
end

local uiData = class {}

local uiThing = class { data = uiData() }

local uiGroup = class { data = uiData(), index = {}, contents = 0, }
