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
local text = ''                             -- The buffer text.
local col_width_t, rows_t = {}, {}          -- The table containing the column width and the table containing the row tables.
local formulas_t, formulas_key_t = {}, {}   -- The table containing the table formulas and the table containing the sorted keys of formulas_t.

--[[ Evaluate the formulas for the table from formulas_t, resolving the references and inserting the results into the fields.
  @param   --
  @return  --
  @usage   -- ]]
local function evaluate_formulas()
  for _, key in ipairs(formulas_key_t) do     -- Resolve references to formulas.
    for k, _ in pairs(formulas_t) do formulas_t[k] = formulas_t[k]:gsub(key, '('..formulas_t[key]..')') end
  end
  for k, _ in pairs(formulas_t) do            -- Resolve references to other fields.
    for i, j in formulas_t[k]:gmatch('@(%d+)$(%d+)') do
      i, j = tonumber(i), tonumber(j)
      formulas_t[k] = formulas_t[k]:gsub('@'..i..'$'..j, rows_t[i][j])
    end
  end
  for key, formula in pairs(formulas_t) do    -- Insert the results into the fields, resolving the references to other rows or columns.
    local formula_, function_
    local i, j = key:match('@(%d+)'), key:match('$(%d+)')

    i, j = tonumber(i), tonumber(j)
    if i and j then
      for k in formula:gmatch('@(%d+)') do formula = formula:gsub('@'..k, rows_t[tonumber(k)][j]) end
      for k in formula:gmatch('$(%d+)') do formula = formula:gsub('$'..k, rows_t[i][tonumber(k)]) end
      function_ = load('return '..formula)
      if function_ then rows_t[i][j] = tostring(function_()) end
    elseif i then
      for k in formula:gmatch('$(%d+)') do formula = formula:gsub('$'..k, rows_t[i][tonumber(k)]) end
      for j = 1, #col_width_t - 1 do
        formula_ = formula
        for k in formula_:gmatch('@(%d+)') do formula_ = formula_:gsub('@'..k, rows_t[tonumber(k)][j]) end
        function_ = load('return '..formula_)
        if function_ then rows_t[i][j] = tostring(function_()) end
      end
    elseif j then
      for k in formula:gmatch('@(%d+)') do formula = formula:gsub('@'..k, rows_t[tonumber(k)][j]) end
      for i = 1, #rows_t do
        formula_ = formula
        if rows_t[i][1] ~= '\\line' then
          for k in formula_:gmatch('$(%d+)') do formula_ = formula_:gsub('$'..k, rows_t[i][tonumber(k)]) end
          function_ = load('return '..formula_)
          if function_ then rows_t[i][j] = tostring(function_()) end
        end
      end
    end
  end
end

--[[ Find the column for the current field.
  @param s  The string containing the row.
  @param p  The current position of the caret on the line.
  @return   The column indicating the current position in the row/string.
  @usage    _M.org.lib.string_len ]]
local function find_column(s, p)
  local i, j
  local len, m = _M.org.lib.string_len(s), 1

  i = s:find('|')
  if p < i then return 0 end

  j = s:find('|', i + 1)
  while j do
    if p >= i and p < j then return m end

    i = j
    j = s:find('|', i + 1)
    m = m + 1
  end

  return m
end

--[[ Get the width for each column depending on the field content.
  @param   --
  @return  --
  @usage   _M.org.lib.string_len ]]
local function get_column_width()
  for _, row_t in ipairs(rows_t) do
    if row_t[1] ~= '\\line' then
      for i, field in ipairs(row_t) do
        local field_width = _M.org.lib.string_len(field)

        if not col_width_t[i + 1] or field_width > col_width_t[i + 1] then col_width_t[i + 1] = field_width end
      end
    end
  end
end

--[[ Get the formulas from the line after the end of the table.
  @param i  The position of the end of the table relative to the buffer.
  @return   'i' as described above and changed to the position of the end of the formula line, if it exists.
  @usage    -- ]]
local function get_formulas(i)
  local j, key, len, s

  s, len = buffer:get_line(buffer:line_from_position(i))
  j = s:find('#%+TBLFM: ')
  if j then
    s = s:sub(j + 9)
    j = s:find('::')
    if j then   -- There is more than one formula.
      for key, val in s:gmatch('::([@$%d]+)=([^:\n]+)') do
        table.insert(formulas_key_t, key)
        formulas_t[key] = val
      end
      s = s:sub(1, j - 1)
    else s = s:sub(1, -2)
    end
    j = s:find('=')
    if j then
      key = s:sub(1, j - 1)
      table.insert(formulas_key_t, key)
      formulas_t[key] = s:sub(j + 1)
    end
    i = i + len
  end

  -- Get the formulas from the table fields, if any new one has been written.
  for j, row_t in ipairs(rows_t) do
    for k, field in ipairs(row_t) do
      if field:sub(1, 1) == '=' then
        key = '@'..j..'$'..k
        if not formulas_t[key] then table.insert(formulas_key_t, key) end
        formulas_t[key] = field:sub(2)
      end
    end
  end

  local function sort_keys(a, b)
    if     a:find('@') and a:find('%$') and (not b:find('@') or not b:find('%$')) then return true
    elseif b:find('@') and b:find('%$') and (not a:find('@') or not a:find('%$')) then return false
    else return a < b
    end
  end
  table.sort(formulas_key_t, sort_keys)

  return i
end

--[[ Get each field of a row.
  @param s  The string containing the row.
  @return   A table with the field contents.
  @usage    _M.org.lib.string_trim ]]
local function get_row(s)
  local i, j
  local c, len, row_t = 1, _M.org.lib.string_len(s), {}

  i = s:find('|') + 1
  if not col_width_t[c] or i - 2 > col_width_t[c] then col_width_t[c] = i - 2 end
  if s:sub(i, i) == '-' then
    row_t[c] = '\\line'
    return row_t
  end

  j = s:find('|', i)
  while j do
    row_t[c] = _M.org.lib.string_trim(s:sub(i, j - 1))
    i = j + 1
    j = s:find('|', i)
    c = c + 1
    col_width_t[c] = 0
  end
  if len > i then row_t[c] = _M.org.lib.string_trim(s:sub(i, len - 1)) end

  return row_t
end

--[[ Get the table from the current position.
  @param   --
  @return  The position of the beginning of the text representing the table relative to the buffer.
  @return  The position of the end of the text representing the table relative to the buffer.
  @return  The column number of the current field.
  @return  The row number of the current field.
  @usage   find_column, get_formulas, get_row ]]
local function get_table()
  local i, j, l, len, m, p, row_t, s
  local n = 1

  col_width_t, rows_t = {}, {}
  formulas_t, formulas_key_t = {}, {}

  p = buffer.current_pos
  l = buffer:line_from_position(p)
  s, len = buffer:get_line(l)
  if not s:find('^ *|') then return end

  table.insert(rows_t, get_row(s))
  i = buffer:position_from_line(l)
  j = i + len
  m = find_column(s, p - i)
  for k = l - 1, 1, -1 do
    s, _ = buffer:get_line(k)
    if not s:find('^ *|') then break end
    table.insert(rows_t, 1, get_row(s))
    i = buffer:position_from_line(k)
    n = n + 1
  end
  for k = l + 1, buffer.line_count do
    s, len = buffer:get_line(k)
    if not s:find('^ *|') then break end
    table.insert(rows_t, get_row(s))
    j = buffer:position_from_line(k) + len
  end

  j = get_formulas(j)
  evaluate_formulas()
  get_column_width()

  return i, j, m, n
end

--[[ Return the string containing the table formulas.
  @param   --
  @return  A string containing the table formulas.
  @usage   -- ]]
local function print_formulas()
  local key, s

  if #formulas_key_t == 0 then return '' end

  key = formulas_key_t[1]
  s = '#+TBLFM: '..key..'='..formulas_t[key]
  for i, ref in ipairs(formulas_key_t) do
    if i > 1 then s = s..'::'..ref..'='..formulas_t[ref] end
  end
  s = s..'\n'

  return s
end

--[[ Return the row with its aligned field contents as a string.
  @param col_width_t  A table with the width of each column.
  @param row_t        A table with the content of each field.
  @param m            The column number of the current field.
  @return             A string containing the row.
  @return             The position in the string for the current field.
  @usage              _M.org.lib.string_pad_with_space ]]
local function print_row(row_t, m)
  local p, s

  s = string.rep(' ', col_width_t[1])..'|'
  if m == 0 then p = s:len() - 1 end
  for i = 1, #col_width_t - 1 do
    if m and i == m then p = _M.org.lib.string_len(s) + 1 end
    if row_t[1] == '\\line' then
      if i == #col_width_t - 1 then s = s..'-'..string.rep('-', col_width_t[i + 1])..'-|'
      else                          s = s..'-'..string.rep('-', col_width_t[i + 1])..'-+'
      end
    else
      row_t[i] = row_t[i] or ''   -- There may be rows with less fields defined.
      if row_t[i]:find('^%d+$') then s = s..' '.._M.org.lib.string_pad_with_space(row_t[i], -col_width_t[i + 1])..' |'
      else                           s = s..' '.._M.org.lib.string_pad_with_space(row_t[i],  col_width_t[i + 1])..' |'
      end
    end
  end
  if m == #col_width_t then p = s:len() end
  s = s..'\n'

  return s, p
end

--[[ Delete and print a table.
  @param i  The position of the beginning of the text representing the table relative to the buffer.
  @param j  The position of the end of the text representing the table relative to the buffer.
  @param m  The column number of the current field.
  @param n  The row number of the current field.
  @return   --
  @usage    print_row, _M.org.lib.string_len ]]
local function reprint_table(i, j, m, n)
  local q
  local s = ''

  for k, row_t in ipairs(rows_t) do
    local c, p, row_s

    if k == n then c = m else c = nil end
    row_s, p = print_row(row_t, c)
    if p then q = _M.org.lib.string_len(s) + p end
    s = s..row_s
  end
  s = s..print_formulas()

  buffer:delete_range(i, j - i)
  buffer:insert_text(i, s)
  buffer:goto_pos(i + q)
end

--[[ Reset the references in formulas.
  @param id  The identifier, '@' for row or '$' for column.
  @param m   The minimal count for references, which should be changed.
  @param d   The direction, 1 or -1, for the change of the reference.
  @return    --
  @usage     -- ]]
local function reset_references(id, m, d)
  for k = #formulas_key_t, 1, -1 do
    local key =     formulas_key_t[k]
    local formula = formulas_t[key]

    for i in formula:gmatch(id..'(%d+)') do if tonumber(i) >= m and i + d > 0 then formula = formula:gsub(id..i, id..(i + d)) end end
    for i in     key:gmatch(id..'(%d+)') do if tonumber(i) >= m and i + d > 0 then key =         key:gsub(id..i, id..(i + d)) end end
    if key ~= formulas_key_t[k] then
      formulas_t[formulas_key_t[k]] = nil
      formulas_key_t[k] = key
    end
    formulas_t[key] = formula
  end
end

--[[ Check if the caret is on a table.
  @param   --
  @return  A boolean value, which is true, if the caret is on a table.
  @usage   -- ]]
function M.is_table()
  local s, _ = buffer:get_line(buffer:line_from_position(buffer.current_pos))
  return s:find('^ *|')
end

--[[ Insert a horizontal line below current row, and move the cursor into the row below that line.
  @param   --
  @return  --
  @usage   M.move_row, M.move_to_field ]]
function M.move_below_new_line()
  M.move_row(1, 1, '\\line')
  M.move_to_field(0, 2)
end

--[[ Move the current column left/right (d). Kill / 'Insert a new column to the left' the current column (x).
  @param d  -1 or 1 indicating the direction left or right -- 'x' has to be 0, if this parameter is used.
  @param x  -1 or 1 indicating kill or insert.
  @return   --
  @usage    get_table, reprint_table ]]
function M.move_column(d, x)
  local field
  local i, j, m, n = get_table()

  if #col_width_t < 2                      then return end
  if     m < 1 or     m > #col_width_t - 1 then return end
  if m + d < 1 or m + d > #col_width_t - 1 then return end

  for k = 1, #rows_t do
    if rows_t[k][1] ~= '\\line' then
      if     x < 0 then table.remove(rows_t[k], m)
      elseif x > 0 then table.insert(rows_t[k], m, '')
      elseif d ~= 0 then
        field = rows_t[k][m + d]
        rows_t[k][m + d] = rows_t[k][m]
        rows_t[k][m] = field
      end
    end
  end

  if     x < 0 then table.remove(col_width_t, m + 1)
  elseif x > 0 then table.insert(col_width_t, m + 1, 0)
  elseif d ~= 0 then
    field = col_width_t[m + d + 1]
    col_width_t[m + d + 1] = col_width_t[m + 1]
    col_width_t[m + 1] = field
  end

  reset_references('$', m, x)

  reprint_table(i, j, m + d, n)
end

--[[ Move the current row up/down. Kill / 'Insert a new row above' the current row.
  @param d        -1 or 1 indicating the direction up or down. -- 'x' has to be 0, if this parameter is used.
  @param x        -1 or 1 indicating kill or insert.
  @param content  The content for the first field of the row.
  @return         --
  @usage          get_table, reprint_table ]]
function M.move_row(d, x, content)
  local row
  local i, j, m, n = get_table()

  if n + d < 1 or (n + d > #rows_t and content == '') then return end   -- " and content == ''" is needed for M.move_below_new_line.

  if x < 0 then
    table.remove(rows_t, n)
    if n > #rows_t then n = #rows_t end
  elseif x > 0 then table.insert(rows_t, n + d, {content})
  elseif d ~= 0 then
    row = rows_t[n + d]
    rows_t[n + d] = rows_t[n]
    rows_t[n] = row
    n = n + d
  end

  reset_references('@', n, x)

  reprint_table(i, j, m, n)
end

--[[ Re-align the table, move to the next or previous field in the row or column. Creates a new row if necessary.
  @param dx  The column-delta, -1 or 1, i. e. move the caret to the previous or next field in the row.
  @param dy  The row-delta, -1 or 1, i. e. move the caret to the previous or next field in the column.
  @return    --
  @usage     get_table, reprint_table, _M.org.lib.integer_loop ]]
function M.move_to_field(dx, dy)
  local d
  local i, j, m, n = get_table()
  local m_ = m

  m = _M.org.lib.integer_loop(m, dx, 1, #col_width_t - 1)
  if m ~= m_ + dx then
    if     dx < 0 then n = _M.org.lib.integer_loop(n, dx, 1, #rows_t)
    elseif dx > 0 then n = n + dx
    end
  end
  if     dy < 0 then n = _M.org.lib.integer_loop(n, dy, 1, #rows_t)
  elseif dy > 0 then n = n + dy
  end
  for k = 1, n - #rows_t do table.insert(rows_t, {}) end

  reprint_table(i, j, m, n)
end

--[[ Re-align the table without moving the curser.
  @param   --
  @return  --
  @usage   get_table, reprint_table ]]
function M.realign_table()
  local i, j, m, n = get_table()

  if i and j then reprint_table(i, j, m, n) end
end

--[[ Sort the table depending on the field the carret is on.
  @param   --
  @return  --
  @usage   get_table, reprint_table ]]
function M.sort_table(method)
  local i, j, m, n = get_table()
  local p, q = n, n
  local t1, t2 = {}, {}

  if i and j and rows_t[n][1] ~= '\\line' then
    -- Check for the range of continuous rows not separated by a '\\line'.
    for k = n - 1, 1, -1 do     -- Search backward.
      if rows_t[k][1] == '\\line' then break else p = p - 1 end
    end
    for k = n + 1, #rows_t do   -- Search forward.
      if rows_t[k][1] == '\\line' then break else q = q + 1 end
    end

    -- Get the fields from each row in the above determined range, i. e. the part of the column, which should be sorted, sort them and rearrange the rows.
    if p ~= q then
      for k = p, q do table.insert(t1, rows_t[k][m]..'|'..k) end

      if     method == 'a' then table.sort(t1, function(a, b) return a < b end)
      elseif method == 'A' then table.sort(t1, function(a, b) return a > b end)
      elseif method == 'n' then table.sort(t1, function(a, b) return _M.org.lib.table_sort_num_asc(  a:sub(1, a:find('|') - 1), b:sub(1, b:find('|') - 1)) end)
      elseif method == 'N' then table.sort(t1, function(a, b) return _M.org.lib.table_sort_num_desc( a:sub(1, a:find('|') - 1), b:sub(1, b:find('|') - 1)) end)
      elseif method == 't' then table.sort(t1, function(a, b) return _M.org.lib.table_sort_time_asc( a:sub(1, a:find('|') - 1), b:sub(1, b:find('|') - 1)) end)
      elseif method == 'T' then table.sort(t1, function(a, b) return _M.org.lib.table_sort_time_desc(a:sub(1, a:find('|') - 1), b:sub(1, b:find('|') - 1)) end)
      end

      for k, row_t in ipairs(rows_t) do
        if k < p or k > q then table.insert(t2, row_t)
        else                   table.insert(t2, rows_t[tonumber(t1[k - p + 1]:sub(t1[k - p + 1]:find('|') + 1))])
        end
      end
    end
    rows_t = t2

    reprint_table(i, j, m, n)
  end
end

return M
