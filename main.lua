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
require 'ui'

once = true

_APP = "Love-Shader"
_APP_VERSION = "0.2"
_FONT = 'console/font/OxygenMono-Regular.otf'
_SHADER = nil
_QMODE = false
_STATE = "???   " -- or ERROR , or OK    .
_KEYS = "F1] Console F2] Editor F3] Shader F4] Both F6] Compile ALT+C/V] TO/FROM CLIPBOARD F9] QMODE ESC] Exit"

clock = 0
frame = 0
status = { show = true }
shader = { show = false, x = 0, y = 0, w = 0, h = 0 }
editor = { show = true, x = 0, y = 0, w = 0, h = 0 }


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

function doResize(w,h)
	if not edit.window then
		local ew = edit:getColsPxSnap(w)
		local eh = edit:getRowsPxSnap(h)
		edit:resize(ew,eh)
		editor.h = eh
		editor.w = ew
		shader.w = w
		shader.h = h
		shader.x = 0
		shader.y = 0
		_CANVAS = love.graphics.newCanvas(w/2, h/2)
	else
		local ew = edit:getColsPxSnap(w)
		local eh = edit:getRowsPxSnap(math.floor(h / 3))
		editor.h = eh
		editor.w = ew
		edit:makeWindow(ew,eh)
		shader.w = w
		shader.h = h - eh
		shader.x = 0
		shader.y = editor.h
		_CANVAS = love.graphics.newCanvas(shader.w/2, shader.h/2)
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
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	if once then
		console.set("set window_height_percent 100")
		_STATUS = love.graphics.newText(love.graphics.newFont(_FONT, 12), _STATE .. _KEYS)
		 _CANVAS = love.graphics.newCanvas(w/2, h/2)
		once = false
		shader.w = w
		shader.h = h
		editor.w = w
		editor.h = h
		-- enter splitscreen automatically
		editor.show = true
		shader.show = true
		edit.window = true
		doResize(w,h)
	end
	edit:update(dt)
	if shader.show and _SHADER then
		-- update the shader
		setShader(_SHADER,'iTime',clock)
		setShader(_SHADER,'iFrame',frame)
		setShader(_SHADER,'iTimeDelta',dt)
		setShader(_SHADER,'iResolution',{shader.w,shader.h,0})
		if love.mouse.isDown(1) then
			local mpx, mpy = love.mouse.getPosition()
			mpx = mpx - shader.x
			mpy = mpy - shader.y
			if (mpx > 0) and (mpy > 0) then setShader(_SHADER,'iMouse',{mpx,mpy,0-mpx,0-mpy}) end
		end
	end
	clock = clock + dt
	frame = frame + 1
	_STATUS:set(_KEYS)
end

function love.draw()
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	if shader.show and _SHADER then
		if _QMODE then
			-- draw to the smaller canvas and then onto the larger screen
			love.graphics.setCanvas(_CANVAS)
			love.graphics.clear()
			love.graphics.setBlendMode("alpha")
			love.graphics.setShader(_SHADER)
			love.graphics.rectangle('fill',0,0,shader.w/2,shader.h/2)
			love.graphics.setShader()
			love.graphics.setCanvas()
			love.graphics.setColor(1, 1, 1, 1)
	    love.graphics.setBlendMode("alpha", "premultiplied")
			love.graphics.draw(_CANVAS, shader.x, shader.y, 0, 2, 2)
			love.graphics.setBlendMode("alpha")
		else
			-- draw the shader, real simple right now
			love.graphics.setShader(_SHADER)
			love.graphics.rectangle('fill',shader.x,shader.y,shader.w,shader.h)
			love.graphics.setShader()
		end
	end
	if editor.show then edit:draw() end
	if _STATUS and status.show then
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle('fill',0,h-14,w,h)
		love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
		love.graphics.draw(_STATUS,-0.5,h-13.5)
		love.graphics.setColor(0.8, 1.0, 0.8, 1.0)
		love.graphics.draw(_STATUS,0,h-14)
	end
end

function love.textinput(text)
	if editor.show then edit:textinput(text) end
end

function love.keypressed(key, scancode, isrepeat)
	if (key == console.toggle_key) then
		console.toggle()
		shader.show = true
		editor.show = false
	else
		local alt = love.keyboard.isDown('ralt') or love.keyboard.isDown('lalt')
		local ctrl = love.keyboard.isDown('rctrl') or love.keyboard.isDown('lctrl')
		-- capture command keys!
		if key == 'f2' then
			editor.show = true
			edit:makeWindow()
			shader.show = false
		elseif key == 'f3' then
			shader.show = true
			edit:makeWindow()
			doResize(love.graphics.getWidth(),love.graphics.getHeight())
			editor.show = false
		elseif key == 'escape' then
			love.event.quit(0)
		elseif key == 'v' and alt then
			edit = LovEdit( { font = _FONT, font_size = 13, content = love.system.getClipboardText() } )
			lshade(edit:getText())
		elseif key == 'c' and alt then
			love.system.setClipboardText(edit.editorBuffer:getText())
		elseif key == 'f6' then
			lshade(edit:getText())
		elseif key == 'f4' then
			--setup window mode
			editor.show = true
			shader.show = true
			edit.window = true
			doResize(love.graphics.getWidth(),love.graphics.getHeight())
		elseif key == 'f9' then
			_QMODE = not _QMODE
		end
		if editor.show then edit:keypressed(key) end
	end
end

function love.resize(w, h) doResize(w,h) end

function love.wheelmoved(x, y)
	if editor.show then edit:wheelmoved(x,y) end
end
