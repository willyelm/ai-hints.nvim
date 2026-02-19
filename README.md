# sidekick.nvim

A Neovim plugin that detects TODO/FIXME comments and lets you send them to AI tools (Claude, Codex, etc.) with a single keymap.

## Install

```lua
-- lazy.nvim
{
  "willyelm/sidekick.nvim",
  opts = {},
  keys = {
    { "<leader>gz", "<cmd>Sidekick<cr>", desc = "Sidekick AI" },
  },
}
```

## Usage

1. Write a TODO comment in any file
2. Place your cursor on it and press `<leader>gz`
3. A cursor-positioned float opens to select your AI tool
4. If Sidekick captured a TODO/FIXME comment, it sends it directly
5. Otherwise, it opens a multiline prompt in the same float (`Enter` submit, `Shift+Enter` newline)
6. Terminal output appears in that same float window

## Configuration

```lua
{
  "willyelm/sidekick.nvim",
  opts = {
    tools = {
      -- String: shell command opened in a terminal window
      Claude = "claude --permission-mode bypassPermissions",
      Codex = "codex",
      -- Function: full control (receives file_path, line_number, task)
      Custom = function(file, line, task)
        vim.fn.jobstart({ "my-tool", "--file", file, "--task", task })
      end,
    },
    hints = {
      enabled = true,                                          -- show inline hints
      keywords = { "TODO", "FIXME", "HACK", "NOTE", "XXX", "BUG" },
      tip = "Implement with AI",                               -- hint text
    },
    split = {
      direction = "vertical", -- "vertical" or "horizontal"
      size = 50,
    },
    window = {
      mode = "float", -- "float" or "split"
      float = {
        position = "cursor", -- "cursor" or "center" (cursor opens below when possible)
        width = 0.4,         -- capped at 40% of editor width
        height = 0.4,        -- capped at 40% of editor height
        border = "rounded",
        close_on_blur = true, -- close float when it loses focus
      },
    },
  },
}
```

## Requirements

- Neovim >= 0.10.0
- An AI CLI tool installed (e.g. `claude`, `codex`)

## License

MIT
