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

--[[ Get the start and end positions for folding the text.
  @param s  The string, i. e. the subtree, in which to search.
  @param i  The position for the start of the search relative to 's'.
  @param n  The heading level indicating the fold.
  @return   The starting position of the fold.
  @return   The end position of the fold.
  @usage    -- ]]
local function get_fold_positions(s, i, n)
  local j

  -- Get the first heading.
  if i == 0 then
    i = s:find('^%*'..string.rep('%*?', n - 1)..' ', 1)
    if i then i = i - 1 else i = s:find('\n%*'..string.rep('%*?', n - 1)..' ', 1) end
  end

  if i then
    i = i + 1
    j = (s:find('\n%*'..string.rep('%*?', n - 1)..' ', i) or s:len() + 1) - 1
    i = s:find('\n', i)
  end

  return i, j
end

--[[ Get the maximum heading level (number of asterisks at the start of a line) in the file.
  @param s  The string, i. e. the subtree, in which to search.
  @return   The maximum heading level as an integer.
  @usage    -- ]]
local function get_maximum_heading_level(s)
  for k = 5, 1, -1 do
    local j = s:find('\n'..string.rep('%*', k)..' ')
    if j then return s:find(' ', j + 1) - (j + 1) end
  end
  return nil
end

--[[ Test the line from a given position for being a heading.
  @param i  The position, for which to make the test.
  @return   A boolean value, which is true, if 'i' is on a heading.
  @return   The start of the line from position 'i' relative to the text.
  @return   The end of the line from position 'i' relative to the text.
  @usage    -- ]]
local function is_heading(i)
  local b, j, k, l, n, s

  l = buffer:line_from_position(i)
  s, n = buffer:get_line(l)
  b = s:find('^%*+ ')
  j = buffer:position_from_line(l) + 1
  k = j + n - 2

  return b, j, k
end

--[[ Rotate the entire buffer among the states (OVERVIEW, CONTENT, SHOWALL).
  @param   --
  @return  --
  @usage   get_fold_positions, get_maximum_heading_level ]]
local function cycle_globally()
  text = buffer:get_text()
  local first_heading_level = 1
  local i, j, n

  -- Expand all folds, i. e. show all lines.
  buffer:show_lines(buffer:line_from_position(1), buffer:line_from_position(text:len()))

  -- Loop the buffer's cycle state between the bounds (lower = 0 and upper = 2).
  -- 0 = OVERVIEW: Show only the headings of the first level. 1 = CONTENT: Show only headings. 2 = SHOWALL lines.
  buffer.cycle_state = (buffer.cycle_state or 0) + 1
  if buffer.cycle_state > 2 then buffer.cycle_state = 0 end

  if buffer.cycle_state < 2 then
    -- Get the level of the first heading.
    i = text:find('^%*+ ')
    if i then i = i - 1 else i = text:find('\n%*+ ') end
    if i then first_heading_level = text:find(' ', i + 1) - (i + 1) end

    n = get_maximum_heading_level(text) or 5
    if buffer.cycle_state == 0 then n = first_heading_level end
    i, j = get_fold_positions(text, 0, n)
    while i do
      buffer:hide_lines(buffer:line_from_position(i), buffer:line_from_position(j))
      i, j = get_fold_positions(text, i, n)
    end
  end
end

--[[ Rotate current subtree among the states (FOLDED, CHILDREN, SUBTREE).
  @param   --
  @return  --
  @usage   get_fold_positions, get_maximum_heading_level, is_heading ]]
local function cycle_subtree()
  text = buffer:get_text()
  local b, i, j = is_heading(buffer.current_pos)
  local k, l, n, p, q, s

  if b then   -- The current position has to be on a heading.
    k, l = get_fold_positions(text, i, text:find(' ', i) - i)       -- k is the position of the '\n' after the heading and l is the last character of the fold.
    s = text:sub(k, l)                                              -- If the heading has no children, l is the last character of the heading and < k.
    n = get_maximum_heading_level(s)
    if buffer.line_visible[buffer:line_from_position(j + 1)] then   -- The state is either CHILDREN or SUBTREE.
      -- Find the next child (heading, itself having children) in the subtree.
      if n then                               -- There is a heading.
        p, q = get_fold_positions(s, 0, n)    -- This is done for the sub-string s; therefor p and q have an offset of k (the start of the sub-string).
        while p do
          if q > p then break end             -- The heading has children.
          p, q = get_fold_positions(s, p, n)
        end
      end

      if p then                               -- There is a heading with children.
        if buffer.line_visible[buffer:line_from_position(q + k - 1)] then            -- The state is SUBTREE -> FOLDED, i. e. hide all, p ~= q + 1
          buffer:hide_lines(buffer:line_from_position(k), buffer:line_from_position(l))
        else                                                                         -- The state is CHILDREN -> SUBTREE, i. e. show all.
          buffer:show_lines(buffer:line_from_position(k), buffer:line_from_position(l))
        end
      else                          -- There is no child (heading with children).       The state is SUBTREE -> FOLDED, i. e. hide all,
        buffer:hide_lines(buffer:line_from_position(k), buffer:line_from_position(l))
      end
    else                            -- The next line after the heading is hidden, i. e. the state is FOLDED -> CHILDREN.
      buffer:show_lines(buffer:line_from_position(k), buffer:line_from_position(l))
      if n then
        p, q = get_fold_positions(s, 0, n)
        while p do
          buffer:hide_lines(buffer:line_from_position(p + k - 1), buffer:line_from_position(q + k - 1))
          p, q = get_fold_positions(s, p, n)
        end
      end
    end
  end
end

--[[ Rotate the current subtree or the entire buffer.
  @param scope  1 = Cycle a single subtree (heading). 0 = Cycle globally, i. e. all subtrees.
  @return       --
  @usage        cycle_globally, cycle_subtree ]]
-- Public functions.
function M.cycle(scope)
  if     scope == 1 then cycle_subtree()
  elseif scope == 0 then cycle_globally()
  end
end

--[[ Go to the next or previous heading from the current position.
  @param relative  1 = Previous/Next heading (any level). 0 = Back-/Forward to the heading with the same or higher level. -1 = Backward to higher level heading.
  @param d         The direction, in which to go: -1 = Back/Previous. +1 = Forward/Next.
  @return          --
  @usage           is_heading, _M.org.lib.find_heading ]]
function M.goto_heading(relative, d)
  local b, i, n
  local p = buffer.current_pos

  text = buffer:get_text()
  n = 5                                                         -- Any heading level, if relative = 1 and by default.
  b, i, _ = is_heading(p)
  if b then
    if     relative == 0  then n = text:find(' ', i) - i        -- If relative = 0 or -1 and to go to a heading with the same o higher level,
    elseif relative == -1 then n = text:find(' ', i) - i - 1    --   the current position has to be on a heading.
    end
  else
    i = p + 1                                                   -- Reset the 'current position', if it is on a heading.
  end
  if n == 0 then
    i = nil
  else
    if b then
      if     d < 0 and p == i - 1 then i = i - 1
      elseif d > 0                then i = text:find('\n', i) + 1
      end
    end
    i = _M.org.lib.find_heading(text, n, i - 1, d)
    if i then i = i + 1 end
  end
  while i do
    if buffer.line_visible[buffer:line_from_position(i - 1)] then break end
    if     d < 0 then i = i - 1
    elseif d > 0 then i = text:find('\n', i) + 1
    end
    i = _M.org.lib.find_heading(text, n, i - 1, d)
    if i then i = i + 1 end
  end
  if not i and relative == -1 then i = 0 end
  if i then buffer:goto_pos(i - 1) end
end

--[[ Initialize the module reading the file-specific configuration and setting variables.
  @param   --
  @return  --
  @usage   cycle_globally; M.startup_folded ]]
function M.init()
  local state

  if buffer:get_lexer() == 'org' then
    -- Module configuration.
    if     M.startup_folded == 'overview' then buffer.cycle_state = 2
    elseif M.startup_folded == 'content'  then buffer.cycle_state = 0
    end

    -- File-specific configuration.
    state = buffer:get_text():match('\n#%+STARTUP: (%a+)\n')
    if state then
      if     state == 'overview' then buffer.cycle_state = 2
      elseif state == 'content'  then buffer.cycle_state = 0
      elseif state == 'showall'  then buffer.cycle_state = nil
      end
    end

    if buffer.cycle_state then cycle_globally() end
  end
end

--[[ De- or promote the current heading or subtree.
  @param d              -1 = Demote. 1 = Promote.
  @param with_children  If true, the whole subtree is de- or promoted.
  @return               --
  @usage                is_heading, _M.org.lib.find_heading ]]
function M.mote_heading(d, with_children)
  -- @todo: Let pro- and demote work on all headings/subtrees in an active regiion.
  local b, i, j, k, n
  local shift = 0

  text = buffer:get_text()
  b, i, _ = is_heading(buffer.current_pos)
  if b then n = text:find(' ', i) - i end                                         -- Get the current heading level.
  if n and (d > 0 or n > 1) then
    if     d > 0 then buffer:insert_text(i - 1, '*')
    elseif d < 0 then buffer:delete_range(i - 1, 1)
    end

    if with_children then
      i = text:find('\n', i) + 1
      k = (_M.org.lib.find_heading(text, n, i - 1, 1) or (text:len() + 1)) - 1    -- Get the section end.
      j = _M.org.lib.find_heading(text, 0, i - 1, 1)
      if j then j = j + 1 end
      while j and j < k do
        shift = shift + d                                                         -- With the pro-/demotion of a heading,
        if     d > 0 then buffer:insert_text(j + shift - 1, '*')                  --   the positions in 'text' after the beginning of the heading move by 'd'.
        elseif d < 0 then buffer:delete_range(j + shift - 1, 1)
        end
        j = text:find('\n', j) + 1
        j = _M.org.lib.find_heading(text, 0, j - 1, 1)
        if j then j = j + 1 end
      end
    end
  end
end

--[[ Move the current subtree.
  @param d  The direction, -1 (up) or 1 (down), in which to move the subtree.
  @return   --
  @usage    is_heading, _M.org.lib.find_heading ]]
function M.move_subtree(d)
  local b, i, j, k, n, p, s, subtree_visible, x1, x2, y
  local p = buffer.current_pos

  text = buffer:get_text()
  b, i, _ = is_heading(p)
  if b then
    n = text:find(' ', i) - i                           -- Get the current heading level.
    if     d < 0 then j = i - 1
    elseif d > 0 then j = text:find('\n', i) + 1
    end
    k = _M.org.lib.find_heading(text, n, j - 1, d)
    if k then k = k + 1 end
    if k and text:find(' ', k) - k == n then            -- Is there a next/previous heading with the same level?
      if     d > 0 then x1, y = k, i                    -- The beginning of the subtree (x1), which will be cut, and the position (y),
      elseif d < 0 then x1, y = i, k                    --   where the cut subtree will be inserted.
      end

      subtree_visible = buffer.line_visible[buffer:line_from_position(x1) + 1]

      j = text:find('\n', x1) + 1
      x2 = _M.org.lib.find_heading(text, n, j - 1, 1)   -- The end of the subtree, which will be cut.
      if x2 then
        x2 = x2 - 1
        s = text:sub(x1 - 1, x2)                        -- Half-cut = copy.
        buffer:delete_range(x1 - 1, x2 - x1 + 2)        -- Cut = delete.
      else
        x2 = text:len()
        s = text:sub(x1 - 1, x2)
        buffer:delete_range(x1 - 2, x2 - x1 + 2)
      end
      buffer:insert_text(y - 2, s)                      -- Paste.

      -- Re-hide the subtree, if it was hidden before.
      if     d > 0 then p = buffer.current_pos
      elseif d < 0 then p = y + (p - i)
      end
      if not subtree_visible then
        buffer:goto_pos(y - 1)
        cycle_subtree()
        buffer:goto_pos(p)
      elseif d < 0 then buffer:goto_pos(p)
      end
    end
  end
end

return M
