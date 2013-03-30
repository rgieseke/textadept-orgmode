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

-- run and/or compile commands
-- @todo?: as 'upload the (exported) file to a web server' or 'export the file to ASCII/HTML/LATEX/DocBook'
-- _M.textadept.run.compile_command.org = 'compile.exe %(filename)'
-- _M.textadept.run.run_command.org =     'run.exe %(filename)'

-- buffer property setter function
function M.set_buffer_properties()
  buffer.tab_width = 2
  buffer.use_tabs = false
end

-- (Adeptsense)
-- @todo?: ctags/api
--> http://foicica.com/textadept/api/_M.textadept.adeptsense.html

-- [context menu]
-- @todo?: mouse controlled actions
--> http://foicica.com/textadept/api/_M.textadept.menu.html#set_contextmenu

-- [extra snippets]
--> http://foicica.com/textadept/api/_M.textadept.snippets.html
snippets.org = {
  tab = "|---|\n| %0  |\n|---|\n",
  url = "[[%1(URL)][%2(description)]]%0",
  ['*'] = "*%0*",
  ['/'] = "/%0/",
  ['_'] = "_%0_",
}

-- [commands]
M.lib = require 'org.library'
local struct = require 'org.structure'    -- 02
local tables = require 'org.tables'       -- 03
local todo =   require 'org.todo'         -- 05
local tags =   require 'org.tags'         -- 06
local time =   require 'org.time'         -- 08
local agenda = require 'org.agenda'       -- 10

M.text_width = 100                        -- Default: 70
struct.startup_folded = 'overview'        -- Default: 'overview'
todo.keywords = {                         -- Default: { { TODO = { 'TODO' }, DONE = { 'DONE' } } }
  {
    TODO = { 'TODO' },
    DONE = { 'DONE', 'CANCELLED' }
  }
}
agenda.deadline_warning_days = 14         -- Default: 14
agenda.empty_days_omitted_string = 'freie Tage ausgelassen'   -- Default: 'empty days omitted'
agenda.skip_scheduled_if_done = true      -- Default: false
agenda.week_abbr = 'KW'                   -- Default: 'Wk'

events.connect(events.LANGUAGE_MODULE_LOADED, struct.init)
events.connect(events.LANGUAGE_MODULE_LOADED, todo.init)

local function find_command(key_sequence)   -- Handles duplicate key bindings in different contexts.
  local i, s, part_id, part = time.get_timestamp(buffer.current_pos)
  local b = tables.is_table()

  if     key_sequence == '\t' then
    if b then tables.move_to_field( 1, 0) else struct.cycle(1) end
  elseif key_sequence == 's\t' then
    if b then tables.move_to_field(-1, 0) else struct.cycle(0) end
  elseif key_sequence == '\n' then
    if b then tables.move_to_field( 0, 1) else return false end
  elseif key_sequence == 'aleft' then
    if b then tables.move_column(-1,  0) else struct.mote_heading(-1, false) end
  elseif key_sequence == 'aright' then
    if b then tables.move_column( 1,  0) else struct.mote_heading( 1, false) end
  elseif key_sequence == 'asleft' then
    if b then tables.move_column( 0, -1) else struct.mote_heading(-1, true) end
  elseif key_sequence == 'asright' then
    if b then tables.move_column( 0,  1) else struct.mote_heading( 1, true) end
  elseif key_sequence == 'aup' then
    if b then tables.move_row(-1,  0, '') else struct.move_subtree(-1) end
  elseif key_sequence == 'adown' then
    if b then tables.move_row( 1,  0, '') else struct.move_subtree( 1) end
  elseif key_sequence == 'asup' then
    if b then tables.move_row( 0, -1, '') else return false end
  elseif key_sequence == 'asdown' then
    if b then tables.move_row( 0,  1, '') else return false end
  elseif key_sequence == 'sleft' then
    if i then time.change(i, s, 'day',   part, -1) else todo.cycle_state(-1) end
  elseif key_sequence == 'sright' then
    if i then time.change(i, s, 'day',   part,  1) else todo.cycle_state( 1) end
  elseif key_sequence == 'sup' then
    if i then time.change(i, s, part_id, part,  1) else todo.cycle_priority(-1) end
  elseif key_sequence == 'sdown' then
    if i then time.change(i, s, part_id, part, -1) else todo.cycle_priority(1) end
  elseif key_sequence == 'clcc' then
    if b then tables.realign_table() end
  end
end

keys.org = {
-- 02+03
  ['\t'] =      { find_command, '\t' },
  ['s\t'] =     { find_command, 's\t' },
  ['\n'] =      { find_command, '\n' },
  -- ['a\n'] =     {  },
  ['as\n'] =    { todo.insert_new },
  ['aleft'] =   { find_command, 'aleft' },
  ['aright'] =  { find_command, 'aright' },
  ['asleft'] =  { find_command, 'asleft' },
  ['asright'] = { find_command, 'asright' },
  ['aup'] =     { find_command, 'aup' },
  ['adown'] =   { find_command, 'adown' },
  ['asup'] =    { find_command, 'asup' },
  ['asdown'] =  { find_command, 'asdown' },
-- 05+08
  ['sleft'] =   { find_command, 'sleft' },
  ['sright'] =  { find_command, 'sright' },
  ['sup'] =     { find_command, 'sup' },
  ['sdown'] =   { find_command, 'sdown' },
  ['cl'] =      {
  -- 02
    ['cn'] =      { struct.goto_heading,  1,  1 },
    ['cp'] =      { struct.goto_heading,  1, -1 },
    ['cf'] =      { struct.goto_heading,  0,  1 },
    ['cb'] =      { struct.goto_heading,  0, -1 },
    ['cu'] =      { struct.goto_heading, -1, -1 },
  -- 03
    ['cc'] =      { find_command, 'clcc' },
    ['-'] =       { tables.move_row, 1, 1, '\\line' },
    ['<'] =       {
      ['a'] =       { tables.sort_table, 'a' },
      ['n'] =       { tables.sort_table, 'n' },
      ['t'] =       { tables.sort_table, 't' },
      ['A'] =       { tables.sort_table, 'A' },
      ['N'] =       { tables.sort_table, 'N' },
      ['T'] =       { tables.sort_table, 'T' },
    },
    ['\n'] =      { tables.move_below_new_line },
  -- 06
    ['cr'] =      { tags.realign_tags },
  -- 08
    ['.'] =       { time.insert_timestamp, true,  '' },
    ['!'] =       { time.insert_timestamp, false, '' },
    ['cd'] =      { time.insert_timestamp, true,  'D' },
    ['cs'] =      { time.insert_timestamp, true,  'S' },
  -- 10
    ['a'] =       {
      ['a'] =       { agenda.show, 'Agenda for 1 week' },
      ['2'] =       { agenda.show, 'Agenda for 2 weeks' },
      ['4'] =       { agenda.show, 'Agenda for 4 weeks' },
      ['L'] =       { agenda.show, 'Timeline' },
      ['t'] =       { agenda.show, 'TODO items' },
    },
    ['t'] =       {
      ['0'] =       { agenda.show, 'All TODO items' },
      ['1'] =       { agenda.show, 'TODO items' },
      ['2'] =       { agenda.show, 'DONE items' },
      ['s'] =       { agenda.show, 'Scheduled TODO items' },
    },
  },
}

return M
