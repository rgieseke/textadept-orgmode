--[[ Textadept Org module
Copyright (c) 2012-2013 joten

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
--]]

local M = {}
local text = ''

--[[ Create a heading (for the case, that the current position is not on the start of a heading line).
  @param i  The start position of the heading from the current position relative to the buffer.
  @param d  The indentation of the line from the current position.
  @return   The string containing the heading.
  @usage    -- ]]
local function create_heading(i, d)
  local h, s

  if i then h = string.rep('*', text:find(' ', i + 1) - (i + 1))..' TODO '
  else      h = '* TODO '
  end
  if not d then
    h = '\n'..h
    if i then
      s, _ = buffer.get_line(buffer:line_from_position(i) - 1)
      if s == '\n' then h = '\n'..h end
    end
  end

  return h
end

--[[ Find the given keyword in the module's keyword table of todo states.
  @param s  The state/keyword string.
  @return   The index, p, of the table in M.keywords.
  @return   The index, q, of the table in M.keywords[p][key].
  @return   The 'TODO' or 'DONE' table key, key.
  @usage    ; M.keywords ]]
local function find_keyword(s)
  local key, p, q

  for j = 1, #M.keywords do
    for k, keyword in ipairs(M.keywords[j].TODO) do
      if keyword == s then
        p, q, key = j, k, 'TODO'
        break
      end
    end
    if not q then
      for k, keyword in ipairs(M.keywords[j].DONE) do
        if keyword == s then
          p, q, key = j, k, 'DONE'
          break
        end
      end
    end
  end

  return p, q, key
end

--[[ Find the next heading and get the level, state or priority of the heading or todo.
  @param p     The position in buffer, from which to search for a heading.
  @param part  The string determining, which part of the heading to be returned as a string.
  @return      The starting position of the string.
  @return      The string defined by part.
  @usage       create_heading, find_keyword, _M.org.lib.find_heading ]]
local function get_heading(p, part)
  local d, h, i, j, l, s, state

  l = buffer:line_from_position(p)
  i = buffer:position_from_line(l)
  s, _ = buffer.get_line(l)
  if part == 'LEVEL' then                                           -- Find the previous heading to the position p in text ...
    if p == i then
      if s:find('^%*+ ') then
        d = -1
        h = string.rep('*', s:find(' ') - 1)..' TODO \n'
        s, _ = buffer.get_line(l - 1)
        if s == '\n' then h = h..'\n' end
      else
        d = s:find('[^ ]')
        if d then d = d - 1 else d = 0 end
      end
    end
    if not h then
      if s:find('^%*+ ') then p = i + s:find(' ') end
      j = _M.org.lib.find_heading(text, 0, p, -1)
      h = create_heading(j, d)
    end
    return d, h
  elseif s:find('^%*+ ') then
    state = s:match('^%*+ (%u+) ')
    if     part == 'STATE'    then return i + s:find(' '), state
    elseif part == 'PRIORITY' then
      if state then j, _, _ = find_keyword(state) end               -- Is state a valid keyword?
      if j then state = state..' ' else state = '' end
      return i + (s:find(' %[#[ABC]%]') or s:find(' ') + state:len() - 3) + 2, s:match('^%*+ '..state..'%[#([ABC])%] ')
    end
  else return nil, nil
  end
end

--[[ Get the next or previous keyword from the module's keyword table of todo states.
  @param p, q, key  The return values of find_keyword.
  @param d          Get the next (1) or previous (-1) keyword.
  @return           q + d as q in the arguments, but for the next or previous entry
  @return           The key as in the arguments, but for the next or previous entry.
  @usage            ; M.keywords ]]
local function get_keyword(p, q, key, d)
  if q == 1 and d < 0 then
    if key == 'TODO' then return nil, ''
    else                  return #M.keywords[p].TODO, 'TODO'
    end
  elseif q == #M.keywords[p][key] and d > 0 then
    if key == 'DONE' then return nil, ''
    else                  return 1, 'DONE'
    end
  else
    return q + d, key
  end
end

--[[ Rotate the priority, if the current position is on a heading.
  @param d  The direction, -1 (down) or 1 (up), in which to rotate the priority,
  @return   --
  @usage    get_heading ]]
function M.cycle_priority(d)
  local byte
  local i, s = get_heading(buffer.current_pos, 'PRIORITY')

  if i then       -- It is a heading.
    if s then     -- There is a priority cookie present.
      byte = s:byte() + d
      if byte < 65 or byte > 67 then buffer:delete_range(i - 3, 5)
      else
        buffer:delete_range(i, 1)
        buffer:insert_text(i, string.char(byte))
      end
    elseif d > 0 then buffer:insert_text(i, ' [#A]')
    elseif d < 0 then buffer:insert_text(i, ' [#C]')
    end
  end
end

--[[ Rotate the state between the keywords from the module's keyword table, if the current position is on a heading.
  @param d  The direction, -1 (previous keyword) or 1 (next keyword), in which to rotate the state,
  @return   --
  @usage    find_keyword, get_heading, get_keyword; M.keywords ]]
function M.cycle_state(d)
  local key, p, q
  local i, s = get_heading(buffer.current_pos, 'STATE')

  if i then       -- It is a heading.
    if s then     -- There is a state keyword present.
      p, q, key = find_keyword(s)
      if p then   -- The keyword was found.
        buffer:delete_range(i, s:len())
        q, key = get_keyword(p, q, key, d)
        if q then buffer:insert_text(i, M.keywords[p][key][q])
        else      buffer:delete_range(i, 1)
        end
      end
    elseif d > 0 then buffer:insert_text(i, M.keywords[1].TODO[1]..' ')
    elseif d < 0 then buffer:insert_text(i, M.keywords[1].DONE[#M.keywords[1].DONE]..' ')
    end
  end
end

--[[ Initialize the module reading the file-specific configuration and setting variables.
  @param   --
  @return  --
  @usage   ; M.keywords ]]
function M.init()
  local keywords

  if buffer:get_lexer() == 'org' then
    -- File-specific configuration.
    text = buffer:get_text()
    for s in text:gmatch('\n#%+TODO:( [%a |]+)\n') do
      if s:find(' | ') then
        local b, t = true, { TODO = {}, DONE = {} }

        for keyword in s:gmatch(' ([%a|]+)') do
          if keyword == '|' then b = false
          elseif b then table.insert(t.TODO, keyword)
          else          table.insert(t.DONE, keyword)
          end
        end
        keywords = keywords or {}
        table.insert(keywords, t)
      end
    end
    if keywords then M.keywords = keywords end
  end
end

--[[ Insert a new todo item with a heading level depending on the current position in the buffer.
  @param   --
  @return  --
  @usage   get_heading ]]
function M.insert_new()
  local d, h
  local p = buffer.current_pos

  text = buffer:get_text()
  d, h = get_heading(p, 'LEVEL')
  h = h or '* TODO \n'
  if d and d < 0 then
    buffer:insert_text(-1, h)
    buffer:goto_pos(p + h:gsub('\n', ''):len())
  else
    if d then
      buffer:delete_range(p, d)
    else
      buffer:line_end()
      p = buffer.current_pos
    end
    buffer:insert_text(-1, h)
    buffer:goto_pos(p + h:len())
  end
end

return M
