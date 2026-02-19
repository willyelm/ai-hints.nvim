local config = require("sidekick.config")
local comments = require("sidekick.comments")
local runner = require("sidekick.runner")
local hints = require("sidekick.hints")
local panel = require("sidekick.panel")

local M = {}

local function close_win(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function prompt_from_buf(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local prompt_lines = {}
  local past_header = false
  for _, line in ipairs(lines) do
    if past_header then
      table.insert(prompt_lines, line)
    elseif line == "" then
      past_header = true
    end
  end
  while #prompt_lines > 0 and prompt_lines[#prompt_lines] == "" do
    table.remove(prompt_lines)
  end
  return table.concat(prompt_lines, "\n")
end

local function open_prompt_input(win, tool, file_path, line_num)
  if not win or not vim.api.nvim_win_is_valid(win) then
    win = panel.open_window()
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "filetype", "sidekick")
  vim.api.nvim_buf_set_name(buf, "[Sidekick Prompt]")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Sidekick Prompt",
    "",
    "",
  })

  local function submit()
    local prompt = prompt_from_buf(buf)
    if prompt == "" then
      return
    end
    runner.run_ai_tool(tool, prompt, file_path, line_num, { window = win })
  end

  vim.api.nvim_buf_set_keymap(buf, "i", "<CR>", "", {
    noremap = true,
    callback = submit,
  })
  vim.api.nvim_buf_set_keymap(buf, "i", "<S-CR>", "<CR>", {
    noremap = true,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = submit,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    callback = function()
      close_win(win)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      close_win(win)
    end,
  })
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { 3, 0 })
  vim.cmd("startinsert")
end

local function open_tool_picker(prompt, file_path, line_num)
  local tools = runner.get_tool_names()
  if #tools == 0 then
    vim.notify("Sidekick: no tools configured", vim.log.levels.WARN)
    return
  end
  if #tools == 1 then
    local win = panel.open_window()
    if prompt then
      runner.run_ai_tool(tools[1], prompt, file_path, line_num, { window = win })
    else
      open_prompt_input(win, tools[1], file_path, line_num)
    end
    return
  end

  local win = panel.open_window()
  local buf = vim.api.nvim_win_get_buf(win)
  local idx = 1
  local function render()
    local lines = { "Select AI Tool", "" }
    for i, tool in ipairs(tools) do
      local marker = (i == idx) and "> " or "  "
      table.insert(lines, marker .. tool)
    end
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end

  local function choose()
    local tool = tools[idx]
    if not tool then
      return
    end
    if prompt then
      runner.run_ai_tool(tool, prompt, file_path, line_num, { window = win })
    else
      open_prompt_input(win, tool, file_path, line_num)
    end
  end

  render()
  vim.api.nvim_buf_set_keymap(buf, "n", "j", "", {
    noremap = true,
    callback = function()
      idx = math.min(idx + 1, #tools)
      render()
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
    noremap = true,
    callback = function()
      idx = math.max(idx - 1, 1)
      render()
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "", {
    noremap = true,
    callback = function()
      idx = math.min(idx + 1, #tools)
      render()
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "", {
    noremap = true,
    callback = function()
      idx = math.max(idx - 1, 1)
      render()
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = choose,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    callback = function()
      close_win(win)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      close_win(win)
    end,
  })
end

function M.run_ai()
  local bufnr = vim.api.nvim_get_current_buf()
  local line_num = vim.fn.line(".")
  local line = vim.api.nvim_get_current_line()
  local file_path = vim.fn.expand("%:p")

  if hints.has_keyword(line) then
    local comment_block, start_line = comments.get_comment_block(bufnr, line_num)
    open_tool_picker(comment_block, file_path, start_line)
  else
    open_tool_picker(nil, file_path, line_num)
  end
end

function M.setup(opts)
  config.setup(opts)
  hints.setup_autocmds()

  vim.api.nvim_create_user_command("Sidekick", function()
    require("sidekick").run_ai()
  end, {})

  vim.schedule(function()
    hints.update()
  end)
end

return M
