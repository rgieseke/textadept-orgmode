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

--[[ Timestamp example and positions.
[2012-12-23 So +1w -1d 00:01-23:59]
^    ^     ^                      ^
j   j+5   j+11                    k
--]]

--[[
  @param s  The optional part of the timestamp.
  @param p  The position of the caret relative to the beginning of 's'.
  @return   The identifier of the part and the part itself as a string.
  @usage    -- ]]
local function get_part(s, p)
  local part, part_id

  if     s:find('-%d+[dwmy]') then
    if     p == s:len() then part_id, part = 'alarm_unit',  s:sub(p,  p)
    elseif p > 1        then part_id, part = 'alarm_count', s:sub(2, -2)
    end
  elseif s:find('%+%d+[dwmy]') then
    if     p == s:len() then part_id, part = 'repeat_unit',  s:sub(p,  p)
    elseif p > 1        then part_id, part = 'repeat_count', s:sub(2, -2)
    end
  elseif s:find('%d+:%d+-%d+:%d+') then
    if     p > 0 and p <  3 then part_id, part = 'time1_hour'
    elseif p > 3 and p <  6 then part_id, part = 'time1_min'
    elseif p > 6 and p <  9 then part_id, part = 'time2_hour', s:sub( 7,  8)
    elseif p > 9 and p < 12 then part_id, part = 'time2_min',  s:sub(10, 11)
    end
  elseif s:find('%d+:%d+') then
    if     p > 0 and p <  3 then part_id, part = 'time1_hour'
    elseif p > 3 and p <  6 then part_id, part = 'time1_min'
    end
  end

  return part_id, part
end

--[[
  @param unit  The current unit, d, w, m or y.
  @param d     The amount and direction, 1 or -1, with which 'unit' should be changed.
  @return      The new unit.
  @usage       _M.org.lib.integer_loop ]]
local function loop_unit(unit, d)
  local i, t = 0, {'d', 'w', 'm', 'y'}

  if     unit == 'd' then i = 1
  elseif unit == 'w' then i = 2
  elseif unit == 'm' then i = 3
  elseif unit == 'y' then i = 4
  end

  return t[_M.org.lib.integer_loop(i, d, 1, 4)]
end

--[[
  @param i        The starting position of the string, which should be replaced.
  @param s        The string, which should be replaced.
  @param part_id  The identifier of the part, which should be replaced.
  @param part     The part as a string, which should be changed.
  @param d        The amount, 1 or -1, with which 'part' should be changed.
  @return         --
  @usage          loop_unit, _M.org.lib.get_time, _M.org.lib.integer_loop ]]
function M.change(i, s, part_id, part, d)
  local m, p, t, time

  if not part_id then return end

  p = buffer.current_pos
  buffer:delete_range(i, s:len())
  if part_id == 'delimiter' then
    if part == '[' then s = '<'..s:sub(2, -2)..'>'
    else                s = '['..s:sub(2, -2)..']'
    end
  elseif part_id == 'alarm_unit' then
    s, _ = s:gsub(' %-(%d+)'..part, ' -%1'..loop_unit(part, d))
  elseif part_id == 'repeat_unit' then
    s, _ = s:gsub(' %+(%d+)'..part, ' +%1'..loop_unit(part, d))
  elseif part_id == 'alarm_count' then
    s, _ = s:gsub(' %-'..part..'([dwmy])', ' -'.._M.org.lib.integer_loop(part, d, 0, nil)..'%1')
  elseif part_id == 'repeat_count' then
    s, _ = s:gsub(' %+'..part..'([dwmy])', ' +'.._M.org.lib.integer_loop(part, d, 0, nil)..'%1')
  elseif part_id == 'time2_hour' then
    s, _ = s:gsub('%-%d+:%d+', os.date('-%H:%M', os.time(_M.org.lib.get_time(s, 2)) + d * 60 * 60))
  elseif part_id == 'time2_min' then
    s, _ = s:gsub('%-%d+:%d+', os.date('-%H:%M', os.time(_M.org.lib.get_time(s, 2)) + d * 60 * 5))             -- 5 minute interval
  else
    if part_id == 'year' or part_id == 'month' then
      t = _M.org.lib.get_time(s, 0)
      if part_id == 'month' then
        m = t.month
        t.month = _M.org.lib.integer_loop(t.month, d, 1, 12)
      end
      if part_id == 'year' or m + d ~= t.month then                                                 -- Has t.month been looped?
        t.year = _M.org.lib.integer_loop(t.year, d, 1970, nil)
      end
      time = os.time(t)
    elseif part_id == 'day' or part_id == 'wday' then time = os.time(_M.org.lib.get_time(s, 0)) + d * 86400    -- 1 day has 86400 seconds.
    elseif part_id == 'time1_hour' or part_id == 'time1_min' then
      t = _M.org.lib.get_time(s, 2)
      if t.day then
        if part_id == 'time1_hour' then time = os.time(t) + d * 60 * 60
        else                            time = os.time(t) + d * 60 * 5
        end
        s, _ = s:gsub('%-%d+:%d+', os.date('-%H:%M', time))
      end
      t = _M.org.lib.get_time(s, 1)
      if     part_id == 'time1_hour' then time = os.time(t) + d * 60 * 60
      else                                time = os.time(t) + d * 60 * 5
      end
      s, _ = s:gsub(' %d+:%d+', os.date(' %H:%M', time))
    end
    s, _ = s:gsub('%d+%-%d+%-%d+ [MDFSTW]+[oiraueh]+[neduitn]?', os.date('%Y-%m-%d %a', time))
  end
  buffer:insert_text(i, s)
  buffer:goto_pos(p)
end

--[[
  @param p  The position in the buffer.
  @return   The starting position of the string, which should be changed, in the buffer.
  @return   The string, which should be changed, i. e. the timestamp.
  @return   The identifier of the part, which should be changed.
  @return   The part, which should be changed.
  @usage    get_part; _M.org.lib.timestamp_pattern ]]
function M.get_timestamp(p)
  local i, j, k, l, m, n, part, part_id, r, s
  local pattern = '[<[]'.._M.org.lib.timestamp_pattern..'[]>]'

  l = buffer:line_from_position(p)
  i = buffer:position_from_line(l)
  s, _ = buffer.get_line(l)

  p = p - i                                             -- The position of the caret relative to the beginning of the current line.
  k = s:find('[]>]', p)                                 -- The position of the last character of a timestamp.
  if not k then return end

  r = s:sub(1, k):reverse()
  j = r:find('[<[]')
  if j then j = _M.org.lib.string_len(r) - j + 1 else return end   -- Re-calculate i factoring the reversed string in.
  if not s:sub(j, k):find(pattern) then return end      -- p is not on a timestamp.

  if     p == j      or  p == k      then part_id, part = 'delimiter', s:sub(j, j)
  elseif p >  j      and p <  j +  6 then part_id, part = 'year'
  elseif p >  j +  5 and p <  j +  9 then part_id, part = 'month'
  elseif p >  j +  8 and p <  j + 12 then part_id, part = 'day'
  elseif p >  j + 11 and p <  j + 14 then part_id, part = 'wday'
  else                                                  -- There are optional parts.
    n = j + 14
    for _ = 1, 3 do
      m = n - 1
      n = s:find(' ', m + 2)                            -- Is there more than one optional part?
      if not n or n > k then n = k end
      if p < n or n > k then
        part_id, part = get_part(s:sub(m + 2, n - 1), p - m - 1)
        break
      end
    end
  end
  return i + j - 1, s:sub(j, k), part_id, part
end

--[[
  @param is_active  If this is true, an <active timestamp>, else an [inactive timestam] is inserted.
  @param prefix     If prefix is 'S' or 'D', the keyword SCHEDULED or DEADLINE is prepended and the timestamp is inserted below the current heading.
  @return           --
  @usage            _M.org.lib.find_heading; _M.org.lib.timestamp_pattern ]]
function M.insert_timestamp(is_active, prefix)
  local i, j, k, l, len, line, n
  local p, s = buffer.current_pos, os.date('%Y-%m-%d %a')
  local pattern = '[<[]'.._M.org.lib.timestamp_pattern..'[]>]'

  if is_active then s = '<'..s..'>' else s = '['..s..']' end
  if prefix == 'S' or prefix == 'D' then
    if prefix == 'S' then s = 'SCHEDULED: '..s else s = 'DEADLINE: '..s end
    text = buffer:get_text()
    i = _M.org.lib.find_heading(text, 0, p, -1)
    if not i then return end
    n = text:find(' ', i) - i
    l = buffer:line_from_position(i)
    line, len = buffer.get_line(l + 1)
    i = buffer:position_from_line(l + 1)
    j = line:find('SCHEDULED: '..pattern)
    k = line:find('DEADLINE: '..pattern)
    if j or k or line:find('CLOSED: '..pattern) then
      if (prefix == 'S' and j) or (prefix == 'D' and k) then return end
      if prefix == 'D' and j then
        i = i + line:find('[]>]', j)
        s = ' '..s
      else
        i = i + n
        s = s..' '
      end
    else
      s = string.rep(' ', n)..s..'\n'
    end
    buffer:insert_text(i, s)
  else
    buffer:insert_text(-1, s)
    buffer:goto_pos(p + s:len() - 1)
  end
end

return M
