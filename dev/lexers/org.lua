--[[ Textadept Org module -- Org LPeg lexer
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

local M = { _NAME = 'org' }

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

--[[ Styles. (Headings)
h1 style_class + bold = style_operator
   style_comment (black on black in term)
h5 style_constant = style_error + italic/bold = style_label
   style_default = style_identifier = style_whitespace = style_keyword + bold
h2 style_string = style_regex + bold
h4 style_preproc = style_type + bold
h3 style_function = style_variable + bold
   style_definition, style_nothing, style_embedded, style_number, style_tag
--]]

-- Special keywords.
local style_todo = l.style_error..{  bold = true, italic = false, underline = false }
local style_done = l.style_string..{ bold = true, italic = false, underline = false }

-- Priorities.
local style_priority1 = l.style_class..{    bold = false, italic = true, underline = false }
local style_priority2 = l.style_string..{   bold = false, italic = true, underline = false }
local style_priority3 = l.style_function..{ bold = false, italic = true, underline = false }
local style_priority4 = l.style_preproc..{  bold = false, italic = true, underline = false }
local style_priority5 = l.style_constant..{ bold = false, italic = true, underline = false }

-- Tags.
local style_tags1 = l.style_class..{    bold = true, italic = false, underline = false }
local style_tags2 = l.style_string..{   bold = true, italic = false, underline = false }
local style_tags3 = l.style_function..{ bold = true, italic = false, underline = false }
local style_tags4 = l.style_preproc..{  bold = true, italic = false, underline = false }
local style_tags5 = l.style_constant..{ bold = true, italic = false, underline = false }

-- Font formats.
local style_bold =      l.style_default..{ bold = true,  italic = false, underline = false }
local style_italic =    l.style_default..{ bold = false, italic = true,  underline = false }
local style_underline = l.style_default..{ bold = false, italic = false, underline = true }

M._tokenstyles = {
  { 'TODO',      style_todo },
  { 'DONE',      style_done },
  { 'PRIORITY1', style_priority1 },
  { 'PRIORITY2', style_priority2 },
  { 'PRIORITY3', style_priority3 },
  { 'PRIORITY4', style_priority4 },
  { 'PRIORITY5', style_priority5 },
  { 'TAG1',      style_tags1 },
  { 'TAG2',      style_tags2 },
  { 'TAG3',      style_tags3 },
  { 'TAG4',      style_tags4 },
  { 'TAG5',      style_tags5 },
  { 'BOLD',      style_bold },
  { 'ITALIC',    style_italic },
  { 'UNDERLINE', style_underline }
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
local time_range = (' ' * DD * ':' * DD)^0 * ('-' * DD * ':' * DD)^0
local repeater =   (' +' * l.integer * S('dwmy'))^0
local alarm =      (' -' * l.integer * S('dwmy'))^0
local datetime =   token(l.NUMBER, S('<[')^-1 * date * wday * time_range * repeater * alarm * S('>]')^-1)

-- Special keywords.
local todo = token('TODO', P('TODO'))
local done = token('DONE', P('DONE'))

-- Heading patterns.
local pattern_priority = '[#' * S('ABC') * ']'
local pattern_tags = ':' * (l.word + l.punct)^1 * l.newline
local pattern_h1 = l.starts_line('* ')        -- Heading1.
local pattern_h2 = l.starts_line('** ')       -- Heading2.
local pattern_h3 = l.starts_line('*** ')      -- Heading3.
local pattern_h4 = l.starts_line('**** ')     -- Heading4.
local pattern_h5 = l.starts_line('***** ')    -- Heading5.

-- Heading token parts.
local part_h1 = token(l.CLASS,        (l.nonnewline - S('<[') - (':' * l.word))^0) * datetime^0 * token(l.CLASS,        (l.nonnewline - (':' * l.word))^0)
local part_h2 = token(l.STRING,       (l.nonnewline - S('<[') - (':' * l.word))^0) * datetime^0 * token(l.STRING,       (l.nonnewline - (':' * l.word))^0)
local part_h3 = token(l.FUNCTION,     (l.nonnewline - S('<[') - (':' * l.word))^0) * datetime^0 * token(l.FUNCTION,     (l.nonnewline - (':' * l.word))^0)
local part_h4 = token(l.PREPROCESSOR, (l.nonnewline - S('<[') - (':' * l.word))^0) * datetime^0 * token(l.PREPROCESSOR, (l.nonnewline - (':' * l.word))^0)
local part_h5 = token(l.CONSTANT,     (l.nonnewline - S('<[') - (':' * l.word))^0) * datetime^0 * token(l.CONSTANT,     (l.nonnewline - (':' * l.word))^0)

-- Headings.
local h1 = token(l.CLASS, pattern_h1) *        ((todo + done) * ws)^0 * (token('PRIORITY1', pattern_priority) * ws)^0 * part_h1 * (token('TAG1', pattern_tags))^0
local h2 = token(l.STRING, pattern_h2) *       ((todo + done) * ws)^0 * (token('PRIORITY2', pattern_priority) * ws)^0 * part_h2 * (token('TAG2', pattern_tags))^0
local h3 = token(l.FUNCTION, pattern_h3) *     ((todo + done) * ws)^0 * (token('PRIORITY3', pattern_priority) * ws)^0 * part_h3 * (token('TAG3', pattern_tags))^0
local h4 = token(l.PREPROCESSOR, pattern_h4) * ((todo + done) * ws)^0 * (token('PRIORITY4', pattern_priority) * ws)^0 * part_h4 * (token('TAG4', pattern_tags))^0
local h5 = token(l.CONSTANT, pattern_h5) *     ((todo + done) * ws)^0 * (token('PRIORITY5', pattern_priority) * ws)^0 * part_h5 * (token('TAG5', pattern_tags))^0

-- Keywords.
local keyword = token(l.KEYWORD, word_match { 'SCHEDULED', 'DEADLINE', 'CLOSED' })

-- Tables.
local hline = token(l.STRING, l.starts_line('|') * S('-+')^1)
local vline = token(l.STRING, '|')
-- @todo: This should be more elaborate.

-- Links.
local link = token(l.FUNCTION, '[[' * (l.nonnewline - ' ' - ']')^1 * ']' * ('[' * (l.nonnewline - ']')^1 * ']')^0 * ']')

-- Strings.
local sq_str = P('L')^-1 * l.delimited_range("'", '\\', true, false, '\n')
local dq_str = P('L')^-1 * l.delimited_range('"', '\\', true, false, '\n')
local string = token(l.STRING, sq_str + dq_str)

-- Comments.
local comment = token(l.COMMENT, '/*' * (l.any - '*/')^0 * P('*/')^-1)

M._rules = {
  { 'whitespace', ws },
  { 'heading1',    h1 },
  { 'heading2',    h2 },
  { 'heading3',    h3 },
  { 'heading4',    h4 },
  { 'heading5',    h5 },
  { 'datetime',   datetime },
  { 'keyword',    keyword },
  { 'link',       link },
  { 'bold',       bold },
  { 'italic',     italic },
  { 'underline',  underline },
  { 'string',     string },
  { 'comment',    comment },
  { 'hline',      hline },
  { 'vline',      vline },
  { 'any_char',   l.any_char },
}

return M
