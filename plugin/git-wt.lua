if vim.g.loaded_git_wt then
  return
end
vim.g.loaded_git_wt = true

vim.api.nvim_create_user_command("GitWt", function(opts)
  local git_wt = require("git-wt")
  local ui = require("git-wt.ui")
  local args = opts.fargs

  local subcmd = args[1]

  if not subcmd or subcmd == "" then
    -- No subcommand: open picker
    ui.pick_switch()
    return
  end

  if subcmd == "list" or subcmd == "ls" then
    git_wt.list(function(worktrees)
      local lines = {}
      for _, wt in ipairs(worktrees) do
        local marker = wt.current and "* " or "  "
        table.insert(lines, string.format("%s%-20s %s (%s)", marker, wt.branch, wt.path, wt.head))
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end)
  elseif subcmd == "switch" or subcmd == "cd" or subcmd == "enter" then
    local name = args[2]
    if not name then
      ui.pick_switch()
      return
    end
    -- Find the worktree by branch name and switch
    git_wt.list(function(worktrees)
      for _, wt in ipairs(worktrees) do
        if wt.branch == name then
          git_wt.switch(wt.path)
          return
        end
      end
      vim.notify("git-wt: worktree '" .. name .. "' not found", vim.log.levels.ERROR)
    end)
  elseif subcmd == "create" then
    local name = args[2]
    if not name then
      ui.prompt_create()
      return
    end
    local start_point = args[3]
    git_wt.create(name, start_point)
  elseif subcmd == "delete" or subcmd == "rm" or subcmd == "remove" then
    local name = args[2]
    if not name then
      vim.notify("git-wt: branch name required for delete", vim.log.levels.ERROR)
      return
    end
    local force = args[3] == "--force" or args[3] == "-f"
    git_wt.delete(name, force)
  elseif subcmd == "status" then
    git_wt.list(function(worktrees)
      for _, wt in ipairs(worktrees) do
        if wt.current then
          vim.notify(
            string.format("git-wt: on branch '%s' at %s (%s)", wt.branch, wt.path, wt.head),
            vim.log.levels.INFO
          )
          return
        end
      end
      vim.notify("git-wt: not in a worktree", vim.log.levels.WARN)
    end)
  else
    vim.notify(
      "git-wt: unknown subcommand '" .. subcmd .. "'\n"
        .. "Available: list, switch, create, delete, status\n"
        .. "Or run :GitWt with no args to open picker",
      vim.log.levels.ERROR
    )
  end
end, {
  nargs = "*",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local parts = vim.split(cmd_line, "%s+", { trimempty = true })
    -- Complete subcommands
    if #parts <= 2 and not cmd_line:match("%s$") or (#parts == 1 and cmd_line:match("%s$")) then
      local subcmds = { "list", "switch", "create", "delete", "status" }
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, subcmds)
    end

    -- Complete branch names for switch/delete
    local subcmd = parts[2]
    if subcmd == "switch" or subcmd == "cd" or subcmd == "enter" or subcmd == "delete" or subcmd == "rm" or subcmd == "remove" then
      local stdout = vim.fn.system({ "git-wt", "--json", "--nocd" })
      local ok, worktrees = pcall(vim.json.decode, stdout)
      if ok and type(worktrees) == "table" then
        local branches = {}
        for _, wt in ipairs(worktrees) do
          if wt.branch:find(arg_lead, 1, true) == 1 then
            table.insert(branches, wt.branch)
          end
        end
        return branches
      end
    end

    return {}
  end,
  desc = "Git worktree management via git-wt",
})
