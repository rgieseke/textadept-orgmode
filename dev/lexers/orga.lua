--[[ Textadept Org module -- Org agenda LPeg lexer
Copyright (c) 2012 joten

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

local l = lexer
local token, word_match = l.token, l.word_match
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V

local M = { _NAME = 'orga' }

--[[Overview. Used examples.
* Heading 1-5 (8)
  TODO special color, bold
  DONE special color, bold
  [#priority]
  :tag: bold
<date> / [date] like heading 3, underlined
  keywords: CLOSED: DEADLINE: SCHEDULED: like heading 3, not underlined
| table | like heading 1
[[link][description] ]
formatting:
  *bold*
  /italic/
  _underline_
  +strike+
--]]

-- ToDos.
local style_todo =     l.style_error..{    bold = true,  italic = false, underline = false }
local style_done =     l.style_string..{   bold = true,  italic = false, underline = false }
local style_priority = l.style_function..{ bold = false, italic = true,  underline = false }
local style_tags =     l.style_function..{ bold = true,  italic = false, underline = false }

-- Font formats.
local style_bold =      l.style_default..{ bold = true,  italic = false, underline = false }
local style_italic =    l.style_default..{ bold = false, italic = true,  underline = false }
local style_underline = l.style_default..{ bold = false, italic = false, underline = true }

-- DateTime.
local style_current_date = l.style_number..{ bold = true, italic = false, underline = false }

M._tokenstyles = {
  { 'TODO',         style_todo },
  { 'DONE',         style_done },
  { 'PRIORITY',     style_priority },
  { 'TAG',          style_tags },
  { 'BOLD',         style_bold },
  { 'ITALIC',       style_italic },
  { 'UNDERLINE',    style_underline },
  { 'CURRENT_DATE', style_current_date }
}

-- Whitespace.
local ws = token(l.WHITESPACE, l.space^1)

-- Font formats.
local bold =      token('BOLD',      '*' * l.word^1 * '*')
local italic =    token('ITALIC',    '/' * l.word^1 * '/')
local underline = token('UNDERLINE', '_' * l.alnum^1 * '_')

-- DateTime.
local DD =   l.digit * l.digit
local date = DD * DD * '-' * DD * '-' * DD
local wday = ' ' * word_match {
  'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So',
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
}
local weekday  = word_match {
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag',
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
}
local month = word_match {
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
}
local time_range = (' ' * DD * ':' * DD)^0 * ('-' * DD * ':' * DD)^0
local repeater =   (' +' * l.integer * S('dwmy'))^0
local alarm =      (' -' * l.integer * S('dwmy'))^0
local pattern_datetime1 = S('<[')^-1 * date * wday * time_range * repeater * alarm * S('>]')^-1
local pattern_datetime2 = l.starts_line(weekday) * l.space^1 * DD * '. ' * month * l.space^1 * DD * DD
local datetime = token(l.NUMBER, pattern_datetime1 + pattern_datetime2)

local current_date = token('CURRENT_DATE', l.starts_line(weekday) * l.space^1 * DD * '. ' * month * l.space^1 * DD * DD * '|')
local time = token(l.CLASS, DD * ':' * DD)
local week = token('UNDERLINE', l.starts_line('KW ' * DD * l.space^25) + l.starts_line('Wk ' * DD * l.space^25))

-- ToDos.
local todo = token('TODO', P('TODO'))
local done = token('DONE', P('DONE'))
local priority = token('PRIORITY', '[#' * S('ABC') * ']')
local tags = token('TAG', ':' * (l.word + l.punct)^1 * l.newline)

-- Keywords.
local keyword = token(l.KEYWORD, word_match { 'SCHEDULED', 'DEADLINE', 'CLOSED' })

-- Links.
local link = token(l.FUNCTION, '[[' * (l.nonnewline - ' ' - ']')^1 * ']' * ('[' * (l.nonnewline - ']')^1 * ']')^0 * ']')

-- Strings.
local sq_str = P('L')^-1 * l.delimited_range("'", '\\', true, false, '\n')
local dq_str = P('L')^-1 * l.delimited_range('"', '\\', true, false, '\n')
local string = token(l.STRING, sq_str + dq_str)

-- Comments.
local comment = token(l.COMMENT, '/*' * (l.any - '*/')^0 * P('*/')^-1)

M._rules = {
  { 'whitespace',   ws },
  { 'todo',         todo },
  { 'done',         done },
  { 'priority',     priority },
  { 'tags',         tags },
  { 'current_date', current_date },
  { 'datetime',     datetime },
  { 'time',         time },
  { 'week',         week },
  { 'keyword',      keyword },
  { 'link',         link },
  { 'bold',         bold },
  { 'italic',       italic },
  { 'underline',    underline },
  { 'string',       string },
  { 'comment',      comment },
  { 'any_char',     l.any_char }
}

return M
