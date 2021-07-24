--[[
Jason A. Petrasko forked from josip on the love2d forums,
posted here: https://love2d.org/forums/viewtopic.php?f=5&t=89025&hilit=love+editor
and on GH here: https://github.com/jmiskovic/indeck
no license attached anywhere?
]]

-- make sure we have a class commons implementation!
if (class == nil) then
	class_commons = true
	class = require 'class'
end

local buffer = {} -- platform independant text buffer
local lexer = require 'glsl-lexer'

local clipboard = "" -- shared between buffer instances

--helper functions
local insertCharAt = function(text, c, pos)
  local first = text:sub(1, pos)
  local last = text:sub(pos + 1)
  return first .. c .. last
end

local repeatN = function(n, f, ...)
  for i=1,n do f(...) end
end

local function drawToken(dcon, text, col, row, tokenType)
  local color = dcon.highlighting[tokenType] or {1,1,1}
  local x =  col * dcon.fontWidth
  local y =  row * dcon.fontHeight
  love.graphics.setFont(dcon.font)
  love.graphics.setColor(color[1],color[2],color[3],1.0)
  love.graphics.print(text, x, y)
	love.graphics.setColor(color[1],color[2],color[3],0.7)
	love.graphics.print(text, x+0.2, y+0.2)
end

local function drawRectangle(dcon, col, row, width, tokenType)
  local color = dcon.highlighting[tokenType] or {1,1,1}
  local x =  col * dcon.fontWidth
  local y =  row * dcon.fontHeight
  local width = width * dcon.fontWidth
  local height = dcon.fontHeight
  love.graphics.setColor(color)
  love.graphics.rectangle('fill', x, y, width, height)
end

local function drawRectangleDown(dcon, col, row, width, _height, tokenType)
  local color = dcon.highlighting[tokenType] or {1,1,1}
  local x =  col * dcon.fontWidth
  local y =  row * dcon.fontHeight
  local width = width * dcon.fontWidth
  local height = dcon.fontHeight * _height
  love.graphics.setColor(color)
  love.graphics.rectangle('fill', x, y, width, height)
end

function buffer.new(_dcon, initialText) -- cols, rows, drawToken, drawRectangle, initialText)
  local buffer = {
    -- all coordinates in text space (integers)
    cols = _dcon.cols,
    rows = _dcon.rows,
    name = '',
    cursor    = {x=0, y=1}, -- x is 0-indexed, y is 1-indexed
    selection = {x=0, y=1}, -- x is 0-indexed, y is 1-indexed
    -- selected text spans between cursor and selection marker
    scroll = {x=5, y=0}, -- both 0-indexed
    lines = {}, -- text broken in lines
    lexed = {}, -- text lines broken into tokens
		dcon = _dcon,
    -- 'public' api
    getText = function(self)
      return table.concat(self.lines, "\n")
    end,
    getCursorLine = function(self)
      return self.lines[self.cursor.y]
    end,
    setName = function(self, name)
      self.name = name:gsub("%c", "")
    end,
    setText = function(self, text)
      self.lines = {}
      self.lexed = lexer(text)
      for i, line in ipairs(self.lexed) do
        lineStrings = {}
        for l, token in ipairs(line) do
          table.insert(lineStrings, token.data)
        end
        table.insert(self.lines, table.concat(lineStrings, ""))
      end
      self:updateView()
      self:deselect()
    end,
		newcontext = function(self,_dcon)
			self.cols = _dcon.cols
	    self.rows = _dcon.rows
			self.dcon = _dcon
		end,
    drawCode = function(self)
      local linesToDraw = math.min(self.rows, #(self.lexed)-self.scroll.y)
      local selectionFrom, selectionTo = self:selectionSpan()
      local selectionWidth = (selectionTo.x + selectionTo.y * self.cols) - (selectionFrom.x + selectionFrom.y * self.cols)
			-- background
			drawRectangleDown(self.dcon,0,0,self.cols,self.rows,'background')
      -- highlight cursor line
      if selectionWidth == 0 then
        drawRectangle(self.dcon,-1, self.cursor.y - self.scroll.y, self.cols + 2, 'cursorline')
      end
      -- selection
      local x, y = selectionFrom.x, selectionFrom.y
      drawRectangle(self.dcon,x - self.scroll.x, y - self.scroll.y, selectionWidth, 'selection')
      selectionWidth = selectionWidth - (self.cols - selectionFrom.x)
      while selectionWidth > 0 do
        y = y + 1
        drawRectangle(self.dcon,0 - self.scroll.x, y - self.scroll.y, selectionWidth, 'selection')
        --selectionWidth = selectionWidth - self.lines[y]:len() --self.cols
        selectionWidth = selectionWidth - self.cols
      end
      -- file content
      for y = 1, linesToDraw do
        local x = -self.scroll.x
        local currentLine = y + self.scroll.y
         -- draw cursor line and caret
        if currentLine == self.cursor.y then
          drawToken(self.dcon,"|", self.cursor.x - self.scroll.x - 0.5, y, 'caret')
        end
        -- draw single line of text
        local lineTokens = self.lexed[currentLine]
        for j, token in ipairs(lineTokens) do
          drawToken(self.dcon,token.data, x, y, token.type)
          --print('token',x,y)
          x = x + #token.data
        end
      end
      -- status line
      drawToken(self.dcon,self.statusLine, self.cols - #self.statusLine, 0, 'comment')
    end,
    -- cursor movement
    cursorUp = function(self)
      self.cursor.y = self.cursor.y - 1
      self:updateView()
    end,
    cursorDown = function(self)
      self.cursor.y = self.cursor.y + 1
      self:updateView()
    end,
    cursorJumpUp = function(self)
      repeatN(10, self.cursorUp, self)
    end,
    cursorJumpDown = function(self)
      repeatN(10, self.cursorDown, self)
    end,
    cursorLeft = function(self)
      if self.cursor.x == 0 then
        if self.cursor.y > 1 then
          self:cursorUp()
          self:cursorEnd()
        else
          return false;
        end
      else
        self.cursor.x = self.cursor.x - 1
        self:updateView()
      end
      return true
    end,
    cursorRight = function(self)
      local length = string.len(self.lines[self.cursor.y])
      if self.cursor.x == length then
        if self.cursor.y < #(self.lines) then
          self:cursorDown()
          self:cursorHome()
        else
          return false
        end
      else
        self.cursor.x = self.cursor.x + 1
        self:updateView()
      end
      return true
    end,
    cursorJumpLeft = function(self)
      self:cursorLeft()
      local pattern = self:charAtCursor():find("[%d%l%u]") and "[%d%l%u]" or "%s"
      self:repeatOverPattern(pattern, self.cursorLeft, self)
    end,
    cursorJumpRight = function(self)
      self:cursorRight()
      local pattern = self:charAtCursor():find("[%d%l%u]") and "[%d%l%u]" or "%s"
      self:repeatOverPattern(pattern, self.cursorRight, self)
    end,
    cursorHome = function(self)
      self.cursor.x = 0
      self:updateView()
    end,
    cursorEnd = function(self)
      self.cursor.x = string.len(self.lines[self.cursor.y])
      self:updateView()
    end,
    cursorPageUp = function(self)
      self.cursor.y = self.cursor.y - self.rows
      self:updateView()
    end,
    cursorPageDown = function(self)
      self.cursor.y = self.cursor.y + self.rows
      self:updateView()
    end,
    cursorJumpHome = function(self)
      self.cursor.x, self.cursor.y = 0, 1
      self:updateView()
    end,
    cursorJumpEnd = function(self)
      self.cursor.y = #self.lines
      self.cursor.x = #self.lines[self.cursor.y]
      self:updateView()
    end,
    -- inserting and removing characters
    insertCharacter = function(self, c)
      self:deleteSelection()
      self.lines[self.cursor.y] = insertCharAt(self.lines[self.cursor.y], c, self.cursor.x)
      self:lexLine(self.cursor.y)
      self.cursor.x = self.cursor.x + 1
      self:updateView()
      self:deselect()
    end,
    insertTab = function(self)
      self:deleteSelection()
      self:insertString("  ")
      self:deselect()
    end,
    breakLine = function(self, withoutIndent)
      self:deleteSelection()
      local nl = self.lines[self.cursor.y]
      local bef = nl:sub(1,self.cursor.x)
      local aft = nl:sub(self.cursor.x + 1, #nl)
      local indent = #(bef:match("^%s+") or "")
      self.lines[self.cursor.y] = bef
      self:lexLine(self.cursor.y)
      table.insert(self.lines, self.cursor.y + 1, aft)
      table.insert(self.lexed, self.cursor.y + 1, {})
      self:lexLine(self.cursor.y + 1)
      self:cursorHome()
      self:cursorDown()
      self:deselect()
      if not withoutIndent then
        repeatN(indent, self.insertCharacter, self, " ")
      end
    end,
    deleteRight = function(self)
      if self:isSelected() then
        self:deleteSelection()
      else
        local length = string.len(self.lines[self.cursor.y])
        if length == self.cursor.x then -- end of line
          if self.cursor.y < #self.lines then
            -- if we have another line, remove newline by joining lines
            local nl = self.lines[self.cursor.y] .. self.lines[self.cursor.y + 1]
            self.lines[self.cursor.y] = nl
            self:lexLine(self.cursor.y)
            table.remove(self.lines, self.cursor.y + 1)
            table.remove(self.lexed, self.cursor.y + 1)
          end
        else -- middle of line, remove char
          local nl = self.lines[self.cursor.y]
          local bef = nl:sub(1, self.cursor.x)
          local aft = nl:sub(self.cursor.x + 2, string.len(nl))
          self.lines[self.cursor.y] = bef..aft
          self:lexLine(self.cursor.y)
        end
      end
    end,
    deleteLeft = function(self)
      if self:isSelected() then
        self:deleteSelection()
      elseif self:cursorLeft() then
        self:deleteRight()
      end
    end,
    deleteWord = function(self)
      self:deleteLeft()
      local pattern = self:charAtCursor():find("[%d%l%u]") and "[%d%l%u]" or "%s"
      self:repeatOverPattern(pattern, self.deleteLeft, self)
    end,
    -- clipboard
    cutText = function(self)
      if self:isSelected() then
        self:copyText()
        self:deleteSelection()
      else
        clipboard = self.lines[self.cursor.y] .. '\n'
        table.remove(self.lines, self.cursor.y)
        table.remove(self.lexed, self.cursor.y)
      end
      self:updateView()
    end,
    copyText = function(self)
      if self:isSelected() then
        local selectionFrom, selectionTo = self:selectionSpan()
        local lines = {}
        for y = selectionFrom.y, selectionTo.y do
          local fromX = y == selectionFrom.y and selectionFrom.x  or 0
          local   toX = y == selectionTo.y   and selectionTo.x    or self.lines[y]:len()
          table.insert(lines, self.lines[y]:sub(fromX + 1, toX))
        end
        clipboard = table.concat(lines, '\n')
      else -- copy cursor line
        clipboard = self.lines[self.cursor.y] .. '\n'
      end
    end,
    pasteText = function(self)
      self:deleteSelection()
      self:insertString(clipboard)
    end,
    -- helper functions
    isSelected = function(self)
      return self.selection.x ~= self.cursor.x or self.selection.y ~= self.cursor.y
    end,
    selectionSpan = function(self)
      if self.selection.y * self.cols + self.selection.x < self.cursor.y * self.cols + self.cursor.x then
        return self.selection, self.cursor
      else
        return self.cursor, self.selection
      end
    end,
    deleteSelection = function(self)
      if not self:isSelected() then return end
      local selectionFrom, selectionTo = self:selectionSpan()
      local singleLineChange = selectionFrom.y == selectionTo.y
      local lines = {}
      for y = selectionTo.y, selectionFrom.y, -1 do
        local fromX = y == selectionFrom.y and selectionFrom.x  or 0
        local   toX = y == selectionTo.y   and selectionTo.x    or self.lines[y]:len()
        if y > selectionFrom.y and y < selectionTo.y then
          table.remove(self.lines, y)
          table.remove(self.lexed, y)
        else
          local fromX = y == selectionFrom.y and selectionFrom.x  or 0
          local   toX = y == selectionTo.y   and selectionTo.x    or self.lines[y]:len()
          local bef = self.lines[y]:sub(0, fromX)
          local aft = self.lines[y]:sub(toX + 1, self.lines[y]:len())
          self.lines[y] = bef .. aft
        end
      end
      self.cursor.x, self.cursor.y = selectionFrom.x, selectionFrom.y
      self:deselect()
      if singleLineChange then
        self:lexLine(self.cursor.y)
      else
        self:deleteRight()
        self:lexAll()
      end
      self:updateView()
    end,
    deselect = function(self)
      self.selection.x, self.selection.y = self.cursor.x, self.cursor.y
    end,
    jumpToLine = function(self, lineNumber, columnNumber)
      lineNumber = math.min(lineNumber or 1, #self.lines)
      columnNumber = math.min(columnNumber or 0, #self.lines[lineNumber] - 1)
      self.cursor.x = columnNumber
      self.cursor.y = lineNumber
      self.scroll.y = math.max(lineNumber - math.floor(self.rows / 2), 0)
      self.scroll.x = math.max(columnNumber - math.floor(7 * self.cols / 8), 0)
      self:deselect()
    end,
    insertString = function(self, str)
      local singleLineChange = true
      for c in str:gmatch(".") do
        if c == '\n' then
          singleLineChange = false
          self:deselect()
          self:breakLine(true)
        elseif c:match('%C') then
          self.lines[self.cursor.y] = insertCharAt(self.lines[self.cursor.y], c, self.cursor.x)
          self.cursor.x = self.cursor.x + 1
        end
      end
      if singleLineChange then
        self:lexLine(self.cursor.y)
      else
        self:lexAll()
      end
      self:deselect()
    end,
    charAtCursor = function(self)
      return self.lines[self.cursor.y]:sub(self.cursor.x, self.cursor.x)
    end,
    lexLine = function(self, lineNum)
      self.lexed[lineNum] = lexer(self.lines[lineNum])[1]
    end,
    lexAll = function(self) -- lexing single line cannot handle multiline comments and strings
      self.lexed = lexer(self:getText())
    end,
    updateView = function(self)
      self.cursor.y = math.max(self.cursor.y, 1)
      self.cursor.y = math.min(self.cursor.y, #(self.lines))
      local lineLength = string.len(self.lines[self.cursor.y] or "")
      self.cursor.x = math.max(self.cursor.x, 0)
      self.cursor.x = math.min(self.cursor.x, lineLength)
      if self.cursor.y <= self.scroll.y then
        self.scroll.y = self.cursor.y - 1
      elseif self.cursor.y > self.scroll.y + self.rows then
        self.scroll.y = self.cursor.y - self.rows
      end
      if self.cursor.x < self.scroll.x then
        self.scroll.x = math.max(self.cursor.x - 10, 0)
      elseif self.cursor.x > self.scroll.x + self.cols then
        self.scroll.x = self.cursor.x + 10 - self.cols
      end
      self.statusLine = string.format('L%d C%d  %s', self.cursor.y, self.cursor.x, self.name)
    end,
    repeatOverPattern = function(self, pattern, moveF, ...)
      -- execute moveF() over text as long as character matches pattern and cursor moves
      while self:charAtCursor():match(pattern) do
        local oldX, oldY = self.cursor.x, self.cursor.y
        moveF(...)
        if (oldX == self.cursor.x and oldY == self.cursor.y) then break end
      end
    end,
		setName = function(self,name)
			self.name = name or '?'
			self:updateView()
		end,
  }
  -- generate all select_ and move_ actions
  for _, functionName in ipairs({'Up', 'Down', 'Left', 'Right', 'JumpUp', 'JumpDown', 'JumpLeft', 'JumpRight',
                                               'Home', 'End', 'PageUp', 'PageDown', 'JumpHome', 'JumpEnd'}) do
    buffer['select' .. functionName] = function(self)
      --self.selection = self.selection or {x= self.cursor.x, y= self.cursor.y}
      self['cursor' .. functionName](self)
    end
    buffer['move' .. functionName] = function(self)
      self['cursor' .. functionName](self)
      self:deselect()
    end
  end
  buffer:setText(initialText or "")
  return buffer
end

--[[ Lua pattern matching
str:find(pattern)        finds the first instance of pattern in string and returns its position
str:gmatch(pattern)      when called repeatedly, returns each successive instance of pattern in string
str:gsub(pattern, repl)  returns a string where all instances of pattern in string have been replaced with repl
str:match(pattern)       returns the first instance of pattern in string

X  represents the character X itself as long as it is not a magic character
.   represents any single character
%a  represents all letters A-Z and a-z
%c  represents all control characters such as Null, Tab, Carr.Return, Linefeed, Delete, etc
%d  represents all digits 0-9
%l  represents all lowercase letters a-z
%p  represents all punctuation characters or symbols such as . , ? ! : ; @ [ ] _ { } ~
%s  represents all white space characters such as Tab, Carr.Return, Linefeed, Space, etc
%u  represents all uppercase letters A-Z
%w  represents all alphanumeric characters A-Z and a-z and 0-9
%x  represents all hexadecimal digits 0-9 and A-F and a-f
%z  represents the character with code \000 because embedded zeroes in a pattern do not work

    The upper case letter versions of the above reverses their meaning
    i.e. %A represents all non-letters and %D represents all non-digits

+       one or more repetitions
* or -  zero or more repetitions
?       optional (zero or one occurrence)
%Y      represents the character Y if it is any non-alphanumeric character
        This is the standard way to get a magic character to match itself
        Any punctuation character (even a non magic one) preceded by a % represents itself
        e.g. %% represents % percent and %+ represents + plus
[set]   represents the class which is the union of all characters in the set
        A range of characters is specified by separating first and last character of range with a - hyphen e.g. 1-5
        All classes described above may also be used as components in the set
        e.g. [%w~] (or [~%w]) represents all alphanumeric characters plus the ~ tilde
[^set]  represents the complement of set, where set is interpreted as above
        e.g. [^A-Z] represents any character except upper case letters                                           --]]

local LovEdit = class { drawContext = {} }

LovEdit.keymapping = {
  buffer = {
    ['up']                  = 'moveUp',
    ['down']                = 'moveDown',
    ['left']                = 'moveLeft',
    ['alt+up']              = 'moveJumpUp',
    ['alt+down']            = 'moveJumpDown',
    ['ctrl+left']           = 'moveJumpLeft',
    ['ctrl+right']          = 'moveJumpRight',
    ['right']               = 'moveRight',
    ['home']                = 'moveHome',
    ['end']                 = 'moveEnd',
    ['pageup']              = 'movePageUp',
    ['pagedown']            = 'movePageDown',
    ['ctrl+home']           = 'moveJumpHome',
    ['ctrl+end']            = 'moveJumpEnd',

    ['shift+up']            = 'selectUp',
    ['alt+shift+up']        = 'selectJumpUp',
    ['shift+down']          = 'selectDown',
    ['alt+shift+down']      = 'selectJumpDown',
    ['shift+left']          = 'selectLeft',
    ['ctrl+shift+left']     = 'selectJumpLeft',
    ['ctrl+shift+right']    = 'selectJumpRight',
    ['shift+right']         = 'selectRight',
    ['shift+home']          = 'selectHome',
    ['shift+end']           = 'selectEnd',
    ['shift+pageup']        = 'selectPageUp',
    ['shift+pagedown']      = 'selectPageDown',

    ['tab']                 = 'insertTab',
    ['return']              = 'breakLine',
    ['enter']               = 'breakLine',
    ['delete']              = 'deleteRight',
    ['backspace']           = 'deleteLeft',
    ['ctrl+backspace']      = 'deleteWord',
    ['ctrl+x']              = 'cutText',
    ['ctrl+c']              = 'copyText',
    ['ctrl+v']              = 'pasteText',
  },
  macros = {
    ['ctrl+shift+backspace'] = function(self) editorBuffer:setText("") end,
    ['alt+l']                = function(self) editorBuffer:insertString('love.graphics.') end,
  },
}

LovEdit.highlighting =
{ -- taken from base16-woodland
  background   = {0.05, 0.1, 0.05}, --editor background
  cursorline   = {0.2, 0.2, 0.2}, --cursor background
  caret        = {0.7, 1.0, 0.7}, --cursor
  whitespace   = {0.0, 0.0, 0.0}, --spaces, newlines, tabs, and carriage returns
  comment      = {0.6, 0.6, 0.6}, --either multi-line or single-line comments
  string_start = {0.75, 0.75, 0.5}, --starts and ends of a string. There will be no non-string tokens between these two.
  string_end   = {0.75, 0.75, 0.5},
  string       = {0.9, 0.9, 0.5}, --part of a string that isn't an escape
  escape       = {0.6, 0.9, 0.5}, --a string escape, like \n, only found inside strings
  keyword      = {0.9, 0.6, 0.9}, --keywords. Like "while", "end", "do", etc
	btype        = {0.75, 0.9, 0.75}, --value types
	funcs 			 = {0.75, 0.75, 1.0}, -- functions
  value        = {0.8, 0.5, 0.3}, --special values. Only true, false, and nil
  ident        = {0.9, 0.5, 0.3}, --identifier. Variables, function names, etc
  number       = {0.8, 0.8, 0.3}, --numbers, including both base 10 (and scientific notation) and hexadecimal
  symbol       = {0.8, 0.8, 0.8}, --symbols, like brackets, parenthesis, ., .., etc
  vararg       = {0.792, 0.498, 0.196}, --...
  operator     = {0.7, 0.9, 0.7}, --operators, like +, -, %, =, ==, >=, <=, ~=, etc
  label_start  = {0.615, 0.545, 0.439}, --the starts and ends of labels. Always equal to '::'. Between them there can only be whitespace and label tokens.
  label_end    = {0.615, 0.545, 0.439},
  label        = {0.776, 0.737, 0.694}, --basically an ident between a label_start and label_end.
  unidentified = {0.827, 0.360, 0.360}, --anything that isn't one of the above tokens. Consider them errors. Invalid escapes are also unidentified.
  selection    = {0.207, 0.223, 0.215},
}

function LovEdit:init(conf)
	love.keyboard.setKeyRepeat(true)
	local font = love.graphics.newFont(conf.font, conf.font_size)
  self.drawContext.font = font
  self.drawContext.fontWidth = font:getWidth(' ')
  self.drawContext.fontHeight = font:getHeight()
	self.drawContext.highlighting = self.highlighting
  local width, height = love.graphics.getDimensions()
  self.drawContext.cols = math.floor(width  / self.drawContext.fontWidth)
  self.drawContext.rows = math.floor(height / self.drawContext.fontHeight) - 1
  self.editorBuffer = buffer.new(self.drawContext, conf.content)
	self.editorBuffer:setName(conf.name)
end

function LovEdit:update(dt)
end

function LovEdit:draw()
  self.editorBuffer:drawCode()
end

function LovEdit:keypressed(k)
  if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
    k = 'shift+'.. k
  end
  if love.keyboard.isDown('lalt') then
    k = 'alt+'.. k
  end
  if love.keyboard.isDown('ralt') then
    k = 'ralt+'.. k
  end
  if love.keyboard.isDown('lctrl') then
    k = 'ctrl+'.. k
  end
  if self.keymapping.buffer[k] then
    local functionName = self.keymapping.buffer[k]
    self.editorBuffer[functionName](self.editorBuffer)
  end
  if self.keymapping.macros[k] then
    self.keymapping.macros[k]()
  end
end

function LovEdit:textinput(k)
  if not love.keyboard.isDown('lctrl') and not love.keyboard.isDown('lalt') then
    self.editorBuffer:insertCharacter(k)
  end
end

function LovEdit:resize(w,h)
	self.drawContext.cols = math.floor(w  / self.drawContext.fontWidth)
  self.drawContext.rows = math.floor(h / self.drawContext.fontHeight) - 1
	self.editorBuffer:newcontext(self.drawContext)
end

function LovEdit:setName(name)
	self.editorBuffer:setName(name)
end

function LovEdit:getText()
	return self.editorBuffer:getText()
end

function LovEdit:setText(txt)
	-- TODO
end

return LovEdit
