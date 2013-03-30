--[[ Textadept Org module
Copyright (c) 2013 joten

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

M.timestamp_pattern = '%d+%-%d+%-%d+ [MDFSTW]+[oiraueh]+[neduitn]? ?[+-]?%d*[dwmy]? ?[+-]?%d*[dwmy]? ?%d*:?%d*%-?%d*:?%d*'

--[[ public functions:

  M.find_heading(text, p)
  M.get_time(timestamp, precision)
  M.split_heading(s)

  M.integer_loop(i, d, l, u)
  M.string_len(s)
  M.string_pad_with_space(s, i)
  M.string_trim(s)
  M.table_has_key(t)
  M.table_sort_num_asc(a, b)
  M.table_sort_num_desc(a, b)
  M.table_sort_time_asc(a, b)
  M.table_sort_time_desc(a, b)
]]

--[[ Find the next or previous heading.
  @param text  The string, in which to search.
  @param n     The heading level, for which to search.
  @param p     The position in the buffer, from which to start the search for the heading.
  @param d     The direction, -1 (up / previous heading) or 1 (down / next heading), in which to search.
  @return      The position of the heading, which was found, i. e. the start of the line relative to the buffer.
  @usage       M.string_len ]]
function M.find_heading(text, n, p, d)
  local i, j, l, s
  local pattern = ''

  if     n == 0 then pattern = '%*+'
  elseif n > 0  then pattern = '%*'..string.rep('%*?', n - 1)
  end

  l = buffer:line_from_position(p)
  s, _ = buffer.get_line(l)
  if d < 0 then
    if s:find('^'..pattern..' ') then                                                   -- The line of position p is a heading.
      i = buffer:position_from_line(l)
    else
      s = text:sub(1, p + 1):reverse()                                                  -- p is relative to the buffer, not the text.
      i = s:find(' '..pattern..'\n')
      if i                             then i = M.string_len(s) - s:find('\n', i) + 1   -- Re-calculate i factoring the reversed string in.
      elseif s:find(' '..pattern..'$') then i = 0                                       -- Find a heading at the beginning of the text.
      end
    end
  elseif d > 0 then
    j = buffer:position_from_line(l)
    if p == j and s:find('^'..pattern..' ') then i = j
    else                                         i = text:find('\n'..pattern..' ', p + 1)
    end
  end

  return i
end

--[[ Get the time from a timestamp.
  @param timestamp  A timestamp in the following format: 2012-12-23 So +1w -1d 00:01-23:59.
  @param precision  0 = date only, 1 = date and time 1, 2 = time 2 (of a time range) only
  @return           A table containing the os.date information in '*t'-format.
  @usage            -- ]]
function M.get_time(timestamp, precision)
  local i
  local capture = '(%d+)%-(%d+)%-(%d+) [MDFSTW]+[oiraueh]+[neduitn]? ?[+-]?%d*[dwmy]? ?[+-]?%d*[dwmy]? ?%d*:?%d*-?%d*:?%d*'
  local t = {}

  _, _, t.year, t.month, t.day = timestamp:find(capture)

  if precision == 1 then
    i = timestamp:find(':')
    if i then t.hour, t.min = timestamp:sub(i - 2, i - 1), timestamp:sub(i + 1, i + 2)
    end
  end
  if precision == 2 then
    i = timestamp:find(':')
    if i then
      i = timestamp:find('-', i)
      if i then
        i = timestamp:find(':', i)
        t.hour, t.min = timestamp:sub(i - 2, i - 1), timestamp:sub(i + 1, i + 2)
      else t = {}
      end
    end
  end

  return t
end

--[[ Loop an integer between a lower and upper value.
  @param i  The current integer.
  @param d  The delta, e. g. 1 or -1, with which 'i' should be changed; it should be <= u - l + 1.
  @param l  The lower bound for 'i'.
  @param u  The upper bound for 'i'.
  @return   The new integer, which is l <= i + d <= u.
  @usage    -- ]]
function M.integer_loop(i, d, l, u)
  if (not u and i + d < l) or (not l and i + d > u) then return i end

  i = i + d
  if     l and i < l then i = u - (i - l + 1)
  elseif u and i > u then i = l + (i - u - 1)
  end

  return i
end

--[[ Split the heading into the heading text, the tags and the space between the text and the tags.
  @param s  The string containing the heading.
  @return   The heading text.
  @return   The string containing the tags.
  @return   The length of the space string between the heading text and the tags.
  @usage    M.string_len; _M.org.text_width ]]
function M.split_heading(s)
  local space_width, tags, h = 0, '', s

  if s:find(':\n', -2) then
    tags, h = string.reverse(s):match('\n(:?[%p%w]*:?)%s*(.*)')
    tags, h = tags:reverse(), h:reverse()
    space_width = _M.org.text_width - M.string_len(h) - M.string_len(tags)
  end

  return h, tags, space_width
end

--[[ Calculate the string length factoring UTF-8-encoded german umlauts in.
  @param s  The string, for which the length should be returned.
  @return   The length of the string.
  @usage    -- ]]
function M.string_len(s)
  return s:gsub('ä', '_'):gsub('Ä', '_'):gsub('ö', '_'):gsub('Ö', '_'):gsub('ü', '_'):gsub('Ü', '_'):gsub('ß', '_'):len()
end

--[[ Pad a string with space to the right or left of the string.
  @param s  The string to be padded.
  @param i  The length of the resulting string.
  @return   The padded string.
  @usage    M.string_len ]]
function M.string_pad_with_space(s, i)
  if i < 0 then return string.rep(' ', math.abs(i + M.string_len(s)))..s    -- Pad to the left.
  else          return s..string.rep(' ', math.abs(i - M.string_len(s)))    -- Pad to the right.
  end
end

--[[ Trim a string of all whitespace at the start and end.
  @param s  The string to be trimmed.
  @return   The trimmed string.
  @usage    -- ]]
function M.string_trim(s)
  return s:gsub('^ *', ''):gsub(' *$', '')
end

--[[ Determine, if there is any key-value-pair in the table.
  @param t  The table to be analyzed.
  @return   A boolean value, which is true, if the given table has any key.
  @usage    -- ]]
function M.table_has_key(t)
  local b = false

  for _, _ in pairs(t) do
    b = true
    break
  end

  return b
end

--[[ The comparison function for sorting a table numerically in ascending order.
  @param a  The first argument to be compared.
  @param b  The second argument to be compared.
  @return   A boolean value specifying whether the first argument should be before the second argument in the sequence.
  @usage    -- ]]
function M.table_sort_num_asc(a, b)
  local a_ = tonumber(a)
  local b_ = tonumber(b)

  if a_ and b_ then return a_ < b_
  else              return a  < b
  end
end

--[[ The comparison function for sorting a table numerically in descending order.
  @param a  The first argument to be compared.
  @param b  The second argument to be compared.
  @return   A boolean value specifying whether the first argument should be before the second argument in the sequence.
  @usage    -- ]]
function M.table_sort_num_desc(a, b)
  local a_ = tonumber(a)
  local b_ = tonumber(b)

  if a_ and b_ then return a_ > b_
  else              return a  > b
  end
end

--[[ The comparison function for sorting a table by time in ascending order.
  @param a  The first argument to be compared.
  @param b  The second argument to be compared.
  @return   A boolean value specifying whether the first argument should be before the second argument in the sequence.
  @usage    _M.org.lib.get_time ]]
function M.table_sort_time_asc(a, b)
  local a_ = _M.org.lib.get_time(a)
  local b_ = _M.org.lib.get_time(b)

  if a_.day and b_.day then return os.time(a_) < os.time(b_)
  else                      return         a   <         b
  end
end

--[[ The comparison function for sorting a table by time in descending order.
  @param a  The first argument to be compared.
  @param b  The second argument to be compared.
  @return   A boolean value specifying whether the first argument should be before the second argument in the sequence.
  @usage    _M.org.lib.get_time ]]
function M.table_sort_time_desc(a, b)
  local a_ = _M.org.lib.get_time(a)
  local b_ = _M.org.lib.get_time(b)

  if a_.day and b_.day then return os.time(a_) > os.time(b_)
  else                      return         a   >         b
  end
end

return M
