# git-wt.nvim

A Neovim wrapper for the [git-wt](https://github.com/k1LoW/git-wt) CLI. This plugin does not implement its own worktree logic — it delegates all operations to `git-wt` and provides a Neovim-native interface on top of it.

Switch worktrees from a Telescope picker (or `vim.ui.select`), and Neovim's working directory changes automatically — neo-tree, lualine, and other plugins follow along.

[Japanese documentation / 日本語ドキュメント](docs/ja/README.md)

## Requirements

- Neovim >= 0.10
- [git-wt](https://github.com/k1LoW/git-wt) CLI installed
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, falls back to `vim.ui.select`)

## Installation

### lazy.nvim

```lua
{
  "WataruNishimura/git-wt.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" }, -- optional
  config = function()
    require("git-wt").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "WataruNishimura/git-wt.nvim",
  config = function()
    require("git-wt").setup()
  end,
}
```

## Commands

| Command | Description |
|---|---|
| `:GitWt` | Open picker to select and switch worktree |
| `:GitWt <branch> [start-point]` | Switch to worktree (create if it doesn't exist) |
| `:GitWt list` | List all worktrees |
| `:GitWt delete <branch> [--force]` | Delete a worktree |
| `:GitWt status` | Show current worktree info |

Just like the `git-wt` CLI, `:GitWt <branch>` handles both switching and creation in a single command.

All subcommands and branch names support tab completion.

## Telescope Picker

When Telescope is available, `:GitWt` opens a Telescope picker with the following keymaps:

| Key | Action |
|---|---|
| `<CR>` | Switch to selected worktree |
| `<C-d>` | Delete selected worktree (with confirmation) |

Without Telescope, `vim.ui.select` is used as a fallback.

## Configuration

```lua
require("git-wt").setup({
  -- Path to git-wt binary (default: "git-wt")
  bin = "git-wt",

  -- Show notification after switching (default: true)
  notify = true,

  -- Functions to call after changing directory (default: {})
  hooks = {
    -- Example: refresh neo-tree after switching
    -- function(dir)
    --   vim.cmd("Neotree dir=" .. dir)
    -- end,
  },
})
```

## How It Works

1. Worktree list is fetched via `git-wt --json --nocd`
2. On switch, `vim.cmd("cd ...")` changes the global working directory
3. This fires Neovim's `DirChanged` autocmd
4. Plugins that watch `DirChanged` (neo-tree, lualine, etc.) update automatically

## Lua API

You can use the Lua API directly for custom keymaps or workflows:

```lua
local git_wt = require("git-wt")

-- List worktrees
git_wt.list(function(worktrees)
  -- worktrees: { { path, branch, head, bare, current }, ... }
end)

-- Switch to worktree (create if it doesn't exist)
git_wt.checkout("feature-branch")
git_wt.checkout("feature-branch", "origin/main", function(path)
  -- path is nil on failure
end)

-- Delete a worktree
git_wt.delete("feature-branch", false, function(ok) end)  -- safe delete
git_wt.delete("feature-branch", true, function(ok) end)   -- force delete
```

## Acknowledgements

This plugin is built on top of [git-wt](https://github.com/k1LoW/git-wt) by [@k1LoW](https://github.com/k1LoW). Thanks for creating such a clean and powerful CLI for Git worktree management.

## License

MIT
