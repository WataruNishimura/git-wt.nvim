if vim.g.loaded_git_wt then
  return
end
vim.g.loaded_git_wt = true

local SUBCMDS = { "list", "delete", "status" }

vim.api.nvim_create_user_command("GitWt", function(opts)
  local git_wt = require("git-wt")
  local ui = require("git-wt.ui")
  local args = opts.fargs

  local first = args[1]

  if not first or first == "" then
    -- No args: open picker
    ui.pick_switch()
    return
  end

  if first == "list" or first == "ls" then
    git_wt.list(function(worktrees)
      local lines = {}
      for _, wt in ipairs(worktrees) do
        local marker = wt.current and "* " or "  "
        table.insert(lines, string.format("%s%-20s %s (%s)", marker, wt.branch, wt.path, wt.head))
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end)
  elseif first == "delete" or first == "rm" or first == "-d" or first == "-D" then
    local force = first == "-D"
    local name = args[2]
    if not name then
      vim.notify("git-wt: branch name required for delete", vim.log.levels.ERROR)
      return
    end
    if not force then
      force = args[3] == "--force" or args[3] == "-f"
    end
    git_wt.delete(name, force)
  elseif first == "status" then
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
    -- Treat as: :GitWt <branch> [start-point]
    local name = first
    local start_point = args[2]
    git_wt.checkout(name, start_point)
  end
end, {
  nargs = "*",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local parts = vim.split(cmd_line, "%s+", { trimempty = true })
    local typing_first = #parts <= 2 and not cmd_line:match("%s$") or (#parts == 1 and cmd_line:match("%s$"))

    if typing_first then
      -- Complete subcommands + branch names
      local candidates = vim.list_extend({}, SUBCMDS)
      local stdout = vim.fn.system({ "git-wt", "--json", "--nocd" })
      local ok, worktrees = pcall(vim.json.decode, stdout)
      if ok and type(worktrees) == "table" then
        for _, wt in ipairs(worktrees) do
          table.insert(candidates, wt.branch)
        end
      end
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, candidates)
    end

    -- Complete branch names for delete
    local subcmd = parts[2]
    if subcmd == "delete" or subcmd == "rm" or subcmd == "-d" or subcmd == "-D" then
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
