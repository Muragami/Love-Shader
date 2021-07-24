--[[
Jason A. Petrasko - muragami@wishray.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--]]

class_commons = true
class = require 'class'

console = require 'console.console'
LovEdit = require 'lovedit'

once = true

_APP = "Love-Shader"
_APP_VERSION = "0.1"
_FONT = 'console/font/OxygenMono-Regular.otf'
_SHADER = nil
_STATE = "???   " -- or ERROR , or OK    .
_KEYS = "F1] Console F2] Editor F3] Shader F4] Paste F5] Copy F6] Compile ESC] Exit"

clock = 0
frame = 0
show_editor = true
show_shader = false


function echo(txt)
	for line in string.gmatch(txt,"([^\r\n]*)[\r\n]?") do
   print(line)
	end
end

function errln(txt)
	for line in string.gmatch(txt,"([^\r\n]*)[\r\n]?") do
   console.err(line)
	end
end

function echoln(t)
	for i,v in ipairs(t) do
		print(tostring(i)..'] '..v)
	end
end

function read(name)
	edit = LovEdit( { font = _FONT, font_size = 13, content = love.filesystem.read(name) } )
	edit_name = name
	edit:setName(name)
end

function new(name)
	edit = LovEdit( { font = _FONT, font_size = 13, content = "" } )
	edit_name = name
	edit:setName(name)
end

function rename(name)
	edit_name = name
	edit:setName(name)
end

function save()
	-- write buffer to file
	for i,ln in ipairs(edit.editorBuffer.lines) do

	end
end

function hide()
	show_editor = false
end

function show()
	show_editor = true
end

function lshade(txt)
	stxt = _VSHADE .. txt
	local ok, ret = pcall(love.graphics.newShader,stxt)
	if ok then
		_SHADER = ret
		_STATE = "OK    "
	else
		-- oops, let's set the status
		_STATE = "ERROR "
		_SHADER = nil
		errln(ret)
	end
end

function love.load(args)
	_VSHADE = love.filesystem.read('var.glsl')
	echo("Welcome to " .. _APP .. " " .. _APP_VERSION)
	if love.filesystem.getInfo( 'shader.glsl', 'file') then
		edit = LovEdit( { font = _FONT, font_size = 13, content = love.filesystem.read('shader.glsl') } )
		lshade(edit.editorBuffer:getText())
	else
		edit = LovEdit( { font = _FONT, font_size = 13, content = "" } )
	end
end

function setShader(shade,uni,val) if shade:hasUniform(uni) then shade:send(uni,val) end end

function love.update(dt)
	if once then
		console.set("set window_height_percent 100")
		_STATUS = love.graphics.newText( love.graphics.newFont(_FONT, 12),
		 _STATE .. _KEYS )
		once = false
	end
	edit:update(dt)
	if show_shader and _SHADER then
		-- update the shader
		setShader(_SHADER,'iTime',clock)
		setShader(_SHADER,'iFrame',frame)
		setShader(_SHADER,'iTimeDelta',dt)
		setShader(_SHADER,'iResolution',{love.graphics.getWidth(),love.graphics.getHeight(),0})
		if love.mouse.isDown(1) then
			local mpx, mpy = love.mouse.getPosition()
			setShader(_SHADER,'iMouse',{mpx,mpy,0-mpx,0-mpy})
		end
	end
	clock = clock + dt
	frame = frame + 1
	_STATUS:set(_STATE .. _KEYS)
end

function love.draw()
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	if show_shader and _SHADER then
		-- draw the shader, real simple right now
		love.graphics.setShader(_SHADER)
		love.graphics.rectangle('fill',0,0,w,h)
		love.graphics.setShader()
	end
	if show_editor then
		edit:draw()
	end
	if _STATUS then
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle('fill',0,h-14,w,h)
		love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
		love.graphics.draw(_STATUS,-0.5,h-13.5)
		love.graphics.setColor(0.8, 1.0, 0.8, 1.0)
		love.graphics.draw(_STATUS,0,h-14)
	end
end

function love.textinput(text)
	edit:textinput(text)
end

function love.keypressed(key, scancode, isrepeat)
	if (key == console.toggle_key) then
		console.toggle()
	else
		-- capture command keys!
		if key == 'f2' then
			show_editor = not show_editor
		elseif key == 'f3' then
			show_shader = not show_shader
		elseif key == 'escape' then
			love.event.quit(0)
		elseif key == 'f4' then
			edit = LovEdit( { font = _FONT, font_size = 13, content = love.system.getClipboardText() } )
			show_editor = true
			show_shader = false
		elseif key == 'f5' then
			love.system.setClipboardText(edit.editorBuffer:getText())
		elseif key == 'f6' then
			lshade(edit:getText())
		end
		edit:keypressed(key)
	end
end

function love.resize(w, h)
  edit:resize(w,h)
end

function love.keyreleased(key, scancode)
end
