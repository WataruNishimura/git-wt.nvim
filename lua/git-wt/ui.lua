local git_wt = require("git-wt")

local M = {}

--- Format a worktree entry for display
---@param wt table
---@return string
local function format_entry(wt)
  local marker = wt.current and "* " or "  "
  return string.format("%s%-20s %s (%s)", marker, wt.branch, wt.path, wt.head)
end

--- Open a picker to switch worktrees (telescope if available, else vim.ui.select)
function M.pick_switch()
  git_wt.list(function(worktrees)
    if #worktrees == 0 then
      vim.notify("git-wt: no worktrees found", vim.log.levels.WARN)
      return
    end

    local has_telescope, _ = pcall(require, "telescope")
    if has_telescope then
      M._telescope_pick(worktrees)
    else
      M._select_pick(worktrees)
    end
  end)
end

--- vim.ui.select fallback picker
---@param worktrees table[]
function M._select_pick(worktrees)
  vim.ui.select(worktrees, {
    prompt = "Switch worktree",
    format_item = function(wt)
      return format_entry(wt)
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.current then
      vim.notify("git-wt: already in this worktree", vim.log.levels.INFO)
      return
    end
    git_wt.switch(choice.path)
  end)
end

--- Telescope picker
---@param worktrees table[]
function M._telescope_pick(worktrees)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 2 },
      { width = 24 },
      { width = 8 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    local wt = entry.value
    return displayer({
      { wt.current and "*" or " ", wt.current and "TelescopeResultsIdentifier" or "" },
      { wt.branch, "TelescopeResultsFunction" },
      { wt.head, "TelescopeResultsComment" },
      { wt.path, "TelescopeResultsComment" },
    })
  end

  pickers
    .new({}, {
      prompt_title = "Git Worktrees",
      finder = finders.new_table({
        results = worktrees,
        entry_maker = function(wt)
          return {
            value = wt,
            display = make_display,
            ordinal = wt.branch .. " " .. wt.path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Enter: switch to worktree
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          local wt = selection.value
          if wt.current then
            vim.notify("git-wt: already in this worktree", vim.log.levels.INFO)
            return
          end
          git_wt.switch(wt.path)
        end)

        -- <C-d>: delete worktree
        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          local wt = selection.value
          if wt.current then
            vim.notify("git-wt: cannot delete current worktree", vim.log.levels.WARN)
            return
          end
          vim.ui.select({ "Yes", "No" }, {
            prompt = "Delete worktree '" .. wt.branch .. "'?",
          }, function(choice)
            if choice == "Yes" then
              actions.close(prompt_bufnr)
              git_wt.delete(wt.branch, false, function(ok)
                if ok then
                  -- Reopen picker
                  M.pick_switch()
                end
              end)
            end
          end)
        end)

        return true
      end,
    })
    :find()
end

--- Prompt user for input to create a worktree
function M.prompt_create()
  vim.ui.input({ prompt = "New worktree branch name: " }, function(name)
    if not name or name == "" then
      return
    end
    vim.ui.input({ prompt = "Start point (empty for HEAD): " }, function(start_point)
      git_wt.create(name, start_point)
    end)
  end)
end

return M
