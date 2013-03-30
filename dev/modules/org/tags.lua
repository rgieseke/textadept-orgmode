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

--[[ Realign the tags of the current heading.
  @param   --
  @return  --
  @usage   _M.org.lib.find_heading, _M.org.lib.split_heading, _M.org.lib.string_len ]]
function M.realign_tags()
  local h, i, n, p, s, s_, space_width, tags

  p = buffer.current_pos
  i = _M.org.lib.find_heading(buffer:get_text(), 0, p, -1)
  if i then
    s, n = buffer:get_line(buffer:line_from_position(i))
    h, tags, space_width = _M.org.lib.split_heading(s)

    s_ = h..string.rep(' ', space_width)..tags..'\n'
    if p > i + n - 1 - _M.org.lib.string_len(tags) then p = p + _M.org.lib.string_len(s_) - _M.org.lib.string_len(s) end

    buffer:delete_range(i, n)
    buffer:insert_text(i, s_)
    buffer:goto_pos(p)
  end
end

return M
