local M = {}

M.defaults = {
	tools = {
		Claude = "claude --permission-mode bypassPermissions",
	},
	hints = {
		enabled = true,
		keywords = { "TODO", "FIXME", "HACK", "NOTE", "XXX", "BUG" },
		tip = "Implement with AI",
	},
	split = {
		direction = "vertical",
		size = 50,
	},
	window = {
		mode = "float", -- "float" or "split"
		float = {
			position = "cursor", -- "cursor" or "center"
			width = 0.4, -- 0..1 ratio of editor width (capped to 40%)
			height = 0.4, -- 0..1 ratio of editor height (capped to 40%)
			border = "rounded",
			close_on_blur = true,
		},
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
