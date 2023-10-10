local M = {}

--- Returns start and end coordinates for visual selection
---@param bufnr integer
---@return table? -- TODO create coordinate struct
local get_visual_selection_coordinates = function(bufnr)
  -- add check for visual selection here
  local start_pos, end_pos = vim.fn.getpos "'<", vim.fn.getpos "'>"
  if not start_pos or not end_pos then
    return nil
  end
  local coordinates = {}
  coordinates.start_row, coordinates.start_col, coordinates.end_row, coordinates.end_col =
    start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3] - 1
  return coordinates
end

local get_text_from_visual_selection = function(bufnr, coordinates)
  return vim.api.nvim_buf_get_text(
    bufnr,
    coordinates.start_row,
    coordinates.start_col,
    coordinates.end_row,
    coordinates.end_col,
    {}
  )
end

--- Converts a multi line string into a table of single line strings
---@param string string multi line input string
---@return string[] table of strings
local multi_line_string_to_table = function(string)
  local string_table = {}
  for line in string:gmatch "[^\n]+" do
    string_table[#string_table + 1] = line
  end
  return string_table
end

local function preview()
  local tempdir = vim.fn.tempname()
  local status = vim.fn.mkdir(tempdir, "p")
  if not status then
    error(
      "failed to create temporary directory at path " .. "'" .. tempdir .. "'"
    )
  end

  local latex_template_path = tempdir .. "/standalone.latex" -- check what tex packages are required. maybe i can just put them in the repo
  local latex_template_table = multi_line_string_to_table(
    require("pandoc-preview.data").latex_template_raw
  )

  if vim.fn.writefile(latex_template_table, latex_template_path) == -1 then
    error "failed to create temporary latex template"
  end

  -- sets our '<'> markers because they are only set after we exit visual mode. theres probably a better solution
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<ESC>", true, false, true),
    "x",
    false
  )

  local coordinates = get_visual_selection_coordinates(vim.fn.bufnr() or 0)
  if not coordinates then
    error "Unable to get visual selection coordinates"
  end

  local markdown =
    get_text_from_visual_selection(vim.fn.bufnr() or 0, coordinates)

  local output_file_name = os.date("%Y-%m-%d %H:%M:%S" .. ".pdf")

  -- do this multithreaded
  local stdout
  local status = vim
    .system({
      "pandoc",
      "--template=" .. latex_template_path,
      "-o",
      tempdir .. "/" .. output_file_name,
    }, {
      stdin = markdown,
    })
    :wait()

  vim
    .system({
      "pdftoppm",
      tempdir .. "/" .. output_file_name,
      "-png",
      "-r",
      "600",
    }, {}, function(obj)
      stdout = obj.stdout
    end)
    :wait()
  vim.fn.writefile(stdout, tempdir .. "/output_file_name.png")
  local image = require("image").from_file(tempdir .. "/output_file_name.png")
  image:render()
end

return M
