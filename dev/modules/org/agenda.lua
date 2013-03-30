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
local agenda_start, agenda_end = 0, 0   -- The time frame for an agenda.
local text = ''                         -- The buffer text.
local times, timetable = {}, {}         -- The timetable and the times (only) from timetable (for sorting prposes) returned by get_timetable(false).

--[[ Leap forward (+) or backward (-) in time.
  @param time       The starting time in seconds from which to leap.
  @param direction  The direction in which to leap, '-' (deadline warning) or '+' (repeat interval).
  @param timestamp  The timestamp from which to get the size of the leap.
  @return           The resulting time in seconds.
  @usage            _M.org.lib.get_time, _M.org.lib.integer_loop; M.deadline_warning_days ]]
local function leap_in_time(time, direction, timestamp)
  local d, m, t
  local i, s = timestamp:match(' %'..direction..'(%d+)([dwmy])')

  if direction == '-' and not i then i, s = M.deadline_warning_days, 'd' end

  if i and s then
    d = tonumber(direction..i)
    if     s == 'd' then time = time + d * 86400
    elseif s == 'w' then time = time + d * 86400 * 7
    elseif s == 'm' or s == 'y' then
      t = _M.org.lib.get_time(timestamp, 1)
      if s == 'm' then
        m = t.month
        t.month = _M.org.lib.integer_loop(t.month, d, 1, 12)
        if m + d ~= t.month then                                          -- Has t.month been looped?
          t.year = _M.org.lib.integer_loop(t.year, tonumber(direction..'1'), 1970, nil)
        end
      elseif s == 'y' then
        t.year = _M.org.lib.integer_loop(t.year, d, 1970, nil)
      end
      time = os.time(t)
    end
  end

  return time
end

--[[ Get the time interval floored to hours, days, weeks, month or years from an os.time depending on its length.
  @param time  The time interval in seconds.
  @return      The time interval floored to hours (h), days (d), weeks (w), month (m) or years (y).
  @usage       _M.org.lib.string_pad_with_space ]]
local function print_time_interval(time)
  time = math.floor(time / 3600)    -- The time interval in hours.

  if time < 48 then return _M.org.lib.string_pad_with_space(time..'h', -4) end

  time = math.floor(time / 24)      -- The time interval in days.

  if time % 7 == 0 then return _M.org.lib.string_pad_with_space((time / 7)..'w', -4) end
  if time > 730 then return '~'.._M.org.lib.string_pad_with_space(math.floor(time / 360)..'y', -3) end
  if time >  60 then return '~'.._M.org.lib.string_pad_with_space(math.floor(time /  30)..'m', -3) end

  return _M.org.lib.string_pad_with_space(time..'d', -4)
end

--[[ Get a section, starting with a heading and ending befor the next heading.
  @param i  The position in the buffer text, from which to start the search for a section.
  @return   The string containing the section text.
  @return   The position of the next heading in the buffer text.
  @usage    -- ]]
local function get_section(i)
  local j, s = nil, ''

  -- Get the first section start.
  if i == 0 then
    i = text:find('^%*+ ')
    if i then i = i - 1 else i = text:find('\n%*+ ') end
  end

  if i then
    i = i + 1
    j = (text:find('\n%*+ ', i) or text:len() + 1) - 1
    s = text:sub(i, j)
    i = text:find('\n%*+ ', i)
  end

  return s, i
end

--[[ Get a subset of a timetable specified by a frame.
  @param t1     The timetable from which to get the subset.
  @param t2     The times from 'timetable' for sorting purposes.
  @param day_1  The os.time for the first day of the frame.
  @param n      The number of days in the time frame.
  @return       The table containing the subset of t1. { 1={time_1_1={heading_1_1_1, ...}, ...}, ..., n={time_n_1={heading_n_1_1, ...}, ...} }
  @usage        -- ]]
local function get_time_frame(t1, t2, day_1, n)
  local t = {}

  for i = 1, n do t[i] = {} end

  for _, time in ipairs(t2) do
    if time >= day_1 + n * 86400 then break end                                 -- 86400 = 24 * 60 * 60, i. e. one day in seconds.

    if time >= day_1 then
      for i = 1, n do                                                           -- Re-index the timetable for the specified time frame.
        if time >= day_1 + (i - 1) * 86400 and time < day_1 + i * 86400 then    -- 86400 = 24 * 60 * 60, i. e. one day in seconds.
          t[i][time] = t1[time]
          i = n + 1
        end
      end
    end
  end

  return t
end

--[[ Get a timetable containing all timestamps and associated headings from the buffer text.
  @param b  A boolean value; if true, inactive timestamps should be found, too.
  @return   A table with the timestamps converted to os.times as keys and the associated headings as values. { time_1={heading_1_1, ...}, ... }
  @return   A table of the times from the above table for sorting purposes. { time_1, ... }
  @usage    get_section, leap_in_time, print_time_interval, _M.org.lib.get_time, _M.org.lib.split_heading; M.skip_scheduled_if_done, _M.org.lib.timestamp_pattern ]]
local function get_timetable(b)
  local h, i, now, now_t, s, space_width, tags, today, tomorrow
  local t1, t2 = {}, {}
  local pattern = '([SCHEDULAINCO]*:?) ?<('.._M.org.lib.timestamp_pattern..')>'

  if b then pattern = '([SCHEDULAINCO]*:?) ?[<[]('.._M.org.lib.timestamp_pattern..')[]>]' end

  now = os.time()
  now_t = os.date('*t', now)
  today = now - (now_t.sec + (now_t.min + (now_t.hour - 12) * 60) * 60)
  tomorrow = today + 86400    -- The end of today is less than the beginning of tomorrow.

  s, i = get_section(0)
  while i do
    h, tags, space_width = _M.org.lib.split_heading((s:match(' ([^\n]*)')..'\n'):gsub(pattern, ''))
    for keyword, timestamp in s:gmatch(pattern) do
      local space, time, time_m, time_n
      local overdue, reminder = 0, 0

      if b or not (M.skip_scheduled_if_done and keyword == 'SCHEDULED:' and h:find('^DONE ')) then
        if keyword ~= '' then keyword = _M.org.lib.string_pad_with_space(keyword, 13) end
        space = string.rep(' ', space_width - 9 - keyword:len())
        time = os.time(_M.org.lib.get_time(timestamp, 1))
        if not t1[time] then
          t1[time] = {}
          table.insert(t2, time)
        end
        table.insert(t1[time], keyword..h..space..tags)

        -- Find repeating entries.
        if not b and agenda_start < agenda_end then
          time_m = time
          time_n = leap_in_time(time_m, '+', timestamp)
          while time_n > time_m and time_n < agenda_end do
            if time_n >= agenda_start then
              if not t1[time_n] then
                t1[time_n] = {}
                table.insert(t2, time_n)
              end
              table.insert(t1[time_n], keyword..h..space..tags)
            end
            time_m = time_n
            time_n = leap_in_time(time_m, '+', timestamp)
          end
        end

        -- Evaluate 'DEADLINE' and 'SCHEDULED' for today, if they are not done.
        if not b and not h:find('^DONE ') then
          if keyword:find('^DEADLINE: +') or keyword:find('^SCHEDULED: +') then
            if keyword:find('^DEADLINE: +') then
                 overdue =  tomorrow - time
                 reminder = tomorrow - leap_in_time(time, '-', timestamp)
            else reminder = tomorrow - time
            end
            if overdue > 0 or reminder > 0 then
              if overdue > 0 then
                   keyword = keyword:sub(1, 5)..'. '..print_time_interval(overdue)..'! '
              else keyword = keyword:sub(1, 5)..'. '..print_time_interval(reminder)..': '
              end
              if not t1[today] then
                t1[today] = {}
                table.insert(t2, today)
              end
              table.insert(t1[today], keyword..h..space..tags)
            end
          end
        end
      end
    end
    s, i = get_section(i)
  end
  table.sort(t2)

  return t1, t2
end

--[[ Get the os.time for the monday of the week containing time.
  @param time  The time, which the week should contain.
  @return      The os.time of monday.
  @usage       -- ]]
local function get_week_start(time)
  local t, wday

  t = os.date('*t', time)
  wday = t.wday - 1                 -- Re-normalize.
  if wday == 0 then wday = 7 end    -- Reset sunday.

  return time - (t.sec + (t.min + (t.hour + (wday - 1) * 24) * 60) * 60)    -- Monday, 00:00 of the same week.
end

--[[ Print the date, i. e. a os.time without the hour, minute and second, in a special format.
  @param time  The os.time for the date to be printed.
  @return      The formatted string.
  @usage       _M.org.lib.string_pad_with_space ]]
local function print_date(time)
  local s = ''

  -- Format: 'Weekday    dd. Month     YYYY''
  s = s.._M.org.lib.string_pad_with_space(os.date('%A', time), 10)
  s = s..os.date('  %d. ', time)
  s = s.._M.org.lib.string_pad_with_space(os.date('%B', time):gsub('\228', 'ä'), 9)
  s = s..os.date(' %Y', time)

  return s
end

--[[ Print the agenda for one day.
  @param day  The os.time of the day to be printed.
  @param t1   The timetable for that day.
  @return     The string representing the daily agenda,
  @usage      print_date ]]
local function print_day(day, t1)
  local postfix, s, t2 = ' ', '', {}    -- t2 will contain all os.times from t1 for sorting purposes.
  local now = os.time()
  local now_t = os.date('*t', now)

  -- Mark today.
  if day == now - (now_t.sec + (now_t.min + now_t.hour * 60) * 60) then
    postfix = '|'
    if t1[now] then table.insert(t1[now], '-- current time --')
    else t1[now] = {'-- current time --'}
    end
  end

  s = s..print_date(day)..postfix..'\n'
  for time, _ in pairs(t1) do table.insert(t2, time) end
  table.sort(t2)
  for _, time in ipairs(t2) do
    if os.date('%H%M', time) == '1200' then   -- Is the time of day specified?
      s = s..'  --:--  '
    else
      s = s..os.date('  %H:%M  ', time)
    end
    s = s..table.concat(t1[time], '\n         ')..'\n'
  end

  return s
end

--[[ Dump the content of tables used by the other functions.
  @param type_  The type of the timetable being dumped.
  @return       The string containing the dumped table.
  @usage        get_time_frame, get_timetable, get_week_start, print_date ]]
local function print_table(type_)
  local day_1, n, t, t1, t2
  local s = ''

  if type_ == '0' then
    for _, time in ipairs(times) do
      local time_s = time..'  '..print_date(time)..'  '
      for i, h in ipairs(timetable[time]) do s = s..time_s..i..': '..h..'\n' end
    end
  elseif type_ == '1' then
    t1, t2 = get_timetable(true)
    for _, time in ipairs(t2) do
      local time_s = time..'  '..print_date(time)..'  '
      for i, h in ipairs(t1[time]) do s = s..time_s..i..': '..h..'\n' end
    end
  elseif type_ == 'a' then
    t = get_time_frame(timetable, times, get_week_start(os.time()), 7)
    for i, _ in ipairs(t) do
      for time, h_t in pairs(t[i]) do
        local time_s = i..': '..time..'  '..print_date(time)..'  '
        for j, h in ipairs(h_t) do s = s..time_s..j..': '..h..'\n' end
      end
    end
  elseif type_ == 'L' then
    t1, t2 = get_timetable(true)
    day_1 = get_week_start(t2[1])
    n = (get_week_start(t2[#t2]) - day_1) / 86400
    t = get_time_frame(t1, t2, day_1, n)
    for i, _ in ipairs(t) do
      for time, h_t in pairs(t[i]) do
        local time_s = i..': '..time..'  '..print_date(time)..'  '
        for j, h in ipairs(h_t) do s = s..time_s..j..': '..h..'\n' end
      end
    end
  end

  return s
end

--[[ Print a timeline of all headings with a date.
  @param   --
  @return  The string representing the timeline.
  @usage   get_time_frame, get_timetable, get_week_start, print_day, _M.org.lib.table_has_key; M.empty_days_omitted_string ]]
local function print_timeline()
  local day_1, n, t
  local m, s = 0, ''
  local t1, t2 = get_timetable(true)

  day_1 = get_week_start(t2[1])
  n = math.ceil((get_week_start(t2[#t2]) - day_1) / 86400) + 6    -- The number of days to be displayed.
  t = get_time_frame(t1, t2, day_1, n)
  for i = 1, n do
    if _M.org.lib.table_has_key(t[i]) then                                         -- If there is no key-value-pair in the timetable for that day (i), the day is empty.
      -- Process empty days.
      if m > 0 then
        if m == 1 and i > 1 then s = s..print_day(day_1 + (i - 2) * 86400, {})
        else                     s = s..'\n[... '..m..' '..M.empty_days_omitted_string..']\n\n'
        end
        m = 0
      end

      s = s..print_day(day_1 + (i - 1) * 86400, t[i])
    else
      m = m + 1                                                   -- Increase the number of continuous empty days.
    end
  end

  return s
end

--[[ Print a todo list containing all todos of the given type.
  @param type_   The type of todos to be listed; e. g. TODO or DONE.
  @param filter  A filter keyword being applied to the found todo items.
  @return        The string containing the list.
  @usage         get_section, _M.org.lib.get_time, _M.org.lib.split_heading; _M.org.lib.timestamp_pattern ]]
local function print_todo_list(type_, filter)
  local b, h, line, space_width, tags
  local list = ''
  local now = os.time()
  local pattern = '([SCHEDULAINCO]*:?) ?<('.._M.org.lib.timestamp_pattern..')>'
  local s, i = get_section(0)

  while i do
    b = true
    line = s:match('^%*+ ('..type_..' [^\n]*)')
    if line then
      if filter == 'Scheduled' then
        for keyword, timestamp in s:gmatch(pattern) do
          local time

          if keyword == 'SCHEDULED:' then
            time = os.time(_M.org.lib.get_time(timestamp, 1))
            if time > now then b = false end
          end
        end
      end
      if b then
        h, tags, space_width = _M.org.lib.split_heading(line..'\n')
        list = list..h..string.rep(' ', space_width)..tags..'\n'
      end
    end

    s, i = get_section(i)
  end

  return list
end

--[[ Print the agenda of the one week containing day_x.
  @param day_x  The day, which the printed week should contain.
  @return       A string representing the week agenda.
  @usage        get_time_frame, get_timetable, get_week_start, print_day, _M.org.lib.string_pad_with_space; M.week_abbr ]]
local function print_week(day_x)
  local day_1, s, t

  day_1 = get_week_start(day_x)
  s = M.week_abbr..os.date(' %W', day_1)
  s = _M.org.lib.string_pad_with_space(s, 30)..'\n'
  t = get_time_frame(timetable, times, day_1, 7)
  for i = 1, 7 do s = s..print_day(day_1 + (i - 1) * 86400, t[i]) end

  return s
end

--[[ Show an agenda, todo list or timeline, depending on type_, in a new buffer in a split view.
  @param type_  The type of overview.
  @return       --
  @usage        print_timeline, print_todo_list, print_week ]]
function M.show(type_)
  local filename, now, s = buffer.filename, os.time(), ''

  agenda_start = get_week_start(now)
  agenda_end =   get_week_start(now) + 4 * 7 * 86400
  text = buffer:get_text()
  timetable, times = get_timetable(false)
  if type_ == 'TODO items' then
    s = s.._M.org.lib.string_pad_with_space('List of '..type_..' of file '..filename, _M.org.text_width)..'\n'
    s = s..print_todo_list('TODO', '')
  elseif type_ == 'DONE items' then
    s = s.._M.org.lib.string_pad_with_space('List of '..type_..' of file '..filename, _M.org.text_width)..'\n'
    s = s..print_todo_list('DONE', '')
  elseif type_ == 'All TODO items' then
    s = s.._M.org.lib.string_pad_with_space('List of '..type_..' of file '..filename, _M.org.text_width)..'\n'
    s = s..print_todo_list('TODO', '')
    s = s..print_todo_list('DONE', '')
  elseif type_ == 'Scheduled TODO items' then
    s = s.._M.org.lib.string_pad_with_space('List of '..type_..' of file '..filename, _M.org.text_width)..'\n'
    s = s..print_todo_list('TODO', 'Scheduled')
  elseif type_ == 'Agenda for 1 week' then
    s = s..print_week(now)
    -- s = s..print_table('a')
  elseif type_ == 'Agenda for 2 weeks' then
    s = s..print_week(now)
    s = s..'\n'..print_week(now + 7 * 86400)
    -- s = s..print_table('1')
  elseif type_ == 'Agenda for 4 weeks' then
    s = s..print_week(now)
    s = s..'\n'..print_week(now + 1 * 7 * 86400)
    s = s..'\n'..print_week(now + 2 * 7 * 86400)
    s = s..'\n'..print_week(now + 3 * 7 * 86400)
  elseif type_ == 'Timeline' then
    s = s.._M.org.lib.string_pad_with_space('Timeline of file '..filename, _M.org.text_width)..'\n'
    s = s..print_timeline()
    -- s = s..print_table('L')
  else
    s = 'Invalid function call: agenda.show('..type_..')'
  end

  local buffer = new_buffer()
  buffer.filename = filename
  buffer:set_lexer('orga')
  buffer:add_text(s)
  buffer:set_save_point()
  buffer.read_only = true
end

return M
