local config = require("sidekick.config")
local panel = require("sidekick.panel")

local M = {}
local sessions = {}
local compose = {
	buf = nil,
	win = nil,
	files = {},
	tool_name = nil,
	tool_cmd = nil,
}

function M.get_tool_names()
	local tools = {}
	for tool_name, _ in pairs(config.options.tools) do
		table.insert(tools, tool_name)
	end
	table.sort(tools)
	return tools
end

local function session_is_alive(session)
	if not session then
		return false
	end
	if not vim.api.nvim_buf_is_valid(session.buf) then
		return false
	end
	local ok, _ = pcall(vim.fn.jobpid, session.job_id)
	return ok
end

local function find_win_for_buf(buf)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return win
		end
	end
	return nil
end

local function open_result_window()
	local split_config = config.options.split
	if split_config.direction == "vertical" then
		vim.cmd(string.format("vsplit | vertical resize %d", split_config.size))
	else
		vim.cmd(string.format("split | resize %d", split_config.size))
	end
	return vim.api.nvim_get_current_win()
end

local function focus_session(session, target_win)
	if target_win and vim.api.nvim_win_is_valid(target_win) then
		vim.api.nvim_win_set_buf(target_win, session.buf)
		vim.api.nvim_set_current_win(target_win)
		return target_win
	end
	local win = find_win_for_buf(session.buf)
	if not win then
		win = open_result_window()
		vim.api.nvim_win_set_buf(win, session.buf)
	end
	vim.api.nvim_set_current_win(win)
	return win
end

local function create_session(tool_name, cmd, win)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_buf_set_name(buf, string.format("[Sidekick %s]", tool_name))

	local job_id = vim.fn.termopen(cmd, {
		on_exit = function()
			sessions[tool_name] = nil
		end,
	})

	vim.api.nvim_create_autocmd("WinResized", {
		buffer = buf,
		callback = function()
			if vim.api.nvim_buf_is_valid(buf) then
				local ok, _ = pcall(vim.fn.jobpid, job_id)
				if ok then
					local w = find_win_for_buf(buf)
					if w then
						vim.fn.jobresize(job_id, vim.api.nvim_win_get_width(w), vim.api.nvim_win_get_height(w))
					end
				end
			end
		end,
	})

	local session = { buf = buf, job_id = job_id }
	sessions[tool_name] = session

	local function close_panel()
		local current_win = vim.api.nvim_get_current_win()
		if vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_win_close(current_win, true)
		end
	end

	vim.keymap.set("t", "<Esc>", function()
		close_panel()
	end, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<Esc>", function()
		close_panel()
	end, { buffer = buf, noremap = true, silent = true })

	return session
end

local function build_prompt_text(files, prompt)
	return "Context Files: " .. table.concat(files, " ") .. " " .. prompt
end

local function start_new_session(tool_name, cmd, files, prompt, target_win)
	local full_prompt = build_prompt_text(files, prompt)
	local win = target_win
	if not win or not vim.api.nvim_win_is_valid(win) then
		win = open_result_window()
	end
	local session = create_session(tool_name, cmd, win)
	vim.schedule(function()
		if session and session_is_alive(session) then
			vim.api.nvim_chan_send(session.job_id, full_prompt .. "\r")
		end
	end)
	vim.cmd("startinsert")
end

local function close_compose()
	if compose.win and vim.api.nvim_win_is_valid(compose.win) then
		vim.api.nvim_win_close(compose.win, true)
	end
	if compose.buf and vim.api.nvim_buf_is_valid(compose.buf) then
		vim.api.nvim_buf_delete(compose.buf, { force = true })
	end
	compose.buf = nil
	compose.win = nil
	compose.files = {}
	compose.tool_name = nil
	compose.tool_cmd = nil
end

local function get_prompt_from_compose()
	if not compose.buf or not vim.api.nvim_buf_is_valid(compose.buf) then
		return ""
	end
	local all_lines = vim.api.nvim_buf_get_lines(compose.buf, 0, -1, false)
	local prompt_lines = {}
	local past_header = false
	for _, line in ipairs(all_lines) do
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

local function submit_compose()
	local prompt = get_prompt_from_compose()
	if prompt == "" then
		return
	end
	local files = compose.files
	local tool_name = compose.tool_name
	local tool_cmd = compose.tool_cmd
	close_compose()
	start_new_session(tool_name, tool_cmd, files, prompt)
end

local function update_compose_header()
	if not compose.buf or not vim.api.nvim_buf_is_valid(compose.buf) then
		return
	end
	local header = { "Context Files:" }
	for _, f in ipairs(compose.files) do
		table.insert(header, "  " .. f)
	end
	table.insert(header, "")
	local all_lines = vim.api.nvim_buf_get_lines(compose.buf, 0, -1, false)
	local prompt_lines = {}
	local past_header = false
	for _, line in ipairs(all_lines) do
		if past_header then
			table.insert(prompt_lines, line)
		elseif line == "" then
			past_header = true
		end
	end
	if #prompt_lines == 0 then
		table.insert(prompt_lines, "")
	end
	local new_lines = {}
	for _, l in ipairs(header) do
		table.insert(new_lines, l)
	end
	for _, l in ipairs(prompt_lines) do
		table.insert(new_lines, l)
	end
	vim.api.nvim_buf_set_lines(compose.buf, 0, -1, false, new_lines)
	local line_count = vim.api.nvim_buf_line_count(compose.buf)
	if compose.win and vim.api.nvim_win_is_valid(compose.win) then
		vim.api.nvim_win_set_cursor(compose.win, { line_count, 0 })
	end
end

local function open_compose(tool_name, cmd)
	if not compose.buf or not vim.api.nvim_buf_is_valid(compose.buf) then
		compose.files = {}
		compose.tool_name = tool_name
		compose.tool_cmd = cmd
		compose.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(compose.buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(compose.buf, "filetype", "sidekick")
		vim.api.nvim_buf_set_name(compose.buf, "[Sidekick Compose]")
		compose.win = panel.open_window()
		vim.api.nvim_win_set_buf(compose.win, compose.buf)
		vim.api.nvim_buf_set_keymap(compose.buf, "i", "<CR>", "", {
			noremap = true,
			callback = submit_compose,
		})
		vim.api.nvim_buf_set_keymap(compose.buf, "i", "<S-CR>", "", {
			noremap = true,
			callback = function()
				vim.api.nvim_paste("\n", true, -1)
			end,
		})
		vim.api.nvim_buf_set_keymap(compose.buf, "n", "q", "", {
			noremap = true,
			callback = close_compose,
		})
	else
		if not compose.win or not vim.api.nvim_win_is_valid(compose.win) then
			compose.win = panel.open_window()
			vim.api.nvim_win_set_buf(compose.win, compose.buf)
		end
		vim.api.nvim_set_current_win(compose.win)
	end
end

function M.run_ai_tool(tool_name, prompt, file_path, line_num, opts)
	opts = opts or {}
	local tool = config.options.tools[tool_name]

	if type(tool) == "function" then
		tool(file_path, line_num, prompt)
		return
	end

	local entry = string.format("%s:%d", file_path, line_num or 1)
	local session = sessions[tool_name]

	if prompt then
		local files
		if compose.buf and vim.api.nvim_buf_is_valid(compose.buf) then
			table.insert(compose.files, entry)
			files = compose.files
			close_compose()
		else
			files = { entry }
		end

		if session_is_alive(session) then
			focus_session(session, opts.window)
			vim.api.nvim_chan_send(session.job_id, build_prompt_text(files, prompt) .. "\r")
			vim.cmd("startinsert")
		else
			start_new_session(tool_name, tool, files, prompt, opts.window)
		end
	else
		if session_is_alive(session) then
			focus_session(session, opts.window)
			vim.api.nvim_chan_send(session.job_id, entry .. " ")
			vim.cmd("startinsert")
		else
			open_compose(tool_name, tool)
			table.insert(compose.files, entry)
			update_compose_header()
			vim.cmd("startinsert")
		end
	end
end

return M
