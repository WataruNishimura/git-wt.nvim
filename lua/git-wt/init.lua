local M = {}

M.config = {
  -- Path to git-wt binary
  bin = "git-wt",
  -- Notify after switching worktree
  notify = true,
  -- Hooks to run after cd (e.g., refresh neo-tree)
  hooks = {},
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

--- Run git-wt with arguments and return stdout, stderr, exit code
---@param args string[]
---@param cwd? string
---@param on_done fun(stdout: string, stderr: string, code: integer)
function M.run(args, cwd, on_done)
  local stdout_chunks = {}
  local stderr_chunks = {}

  vim.system(
    vim.list_extend({ M.config.bin }, args),
    {
      cwd = cwd or vim.fn.getcwd(),
      text = true,
    },
    vim.schedule_wrap(function(obj)
      on_done(obj.stdout or "", obj.stderr or "", obj.code)
    end)
  )
end

--- Run git-wt synchronously and return stdout, stderr, exit code
---@param args string[]
---@param cwd? string
---@return string stdout
---@return string stderr
---@return integer code
function M.run_sync(args, cwd)
  local obj = vim.system(
    vim.list_extend({ M.config.bin }, args),
    {
      cwd = cwd or vim.fn.getcwd(),
      text = true,
    }
  ):wait()
  return obj.stdout or "", obj.stderr or "", obj.code
end

--- List worktrees via --json
---@param cb fun(worktrees: table[])
function M.list(cb)
  M.run({ "--json", "--nocd" }, nil, function(stdout, stderr, code)
    if code ~= 0 then
      vim.notify("git-wt: " .. stderr, vim.log.levels.ERROR)
      return
    end
    local ok, parsed = pcall(vim.json.decode, stdout)
    if not ok then
      vim.notify("git-wt: failed to parse JSON", vim.log.levels.ERROR)
      return
    end
    cb(parsed)
  end)
end

--- Change Neovim's cwd and trigger events so neo-tree etc. follow along
---@param dir string
function M.cd(dir)
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  -- tcd/lcd are not used so that the global cwd changes and all plugins follow

  if M.config.notify then
    vim.notify("git-wt: switched to " .. dir)
  end

  -- Run user-defined hooks
  for _, hook in ipairs(M.config.hooks) do
    if type(hook) == "function" then
      hook(dir)
    end
  end
end

--- Switch to a worktree (create if it doesn't exist), mirroring `git wt <branch> [start-point]`
---@param name string branch/worktree name
---@param start_point? string optional start-point for new worktree
---@param cb? fun(path: string?)
function M.checkout(name, start_point, cb)
  local args = { "--nocd", name }
  if start_point and start_point ~= "" then
    table.insert(args, start_point)
  end
  M.run(args, nil, function(stdout, stderr, code)
    if code ~= 0 then
      vim.notify("git-wt: " .. stderr, vim.log.levels.ERROR)
      if cb then cb(nil) end
      return
    end
    -- Find the worktree path from the list and cd to it
    M.list(function(worktrees)
      for _, wt in ipairs(worktrees) do
        if wt.branch == name then
          M.cd(wt.path)
          if cb then cb(wt.path) end
          return
        end
      end
      vim.notify("git-wt: could not find worktree path for '" .. name .. "'", vim.log.levels.WARN)
      if cb then cb(nil) end
    end)
  end)
end

--- Delete a worktree
---@param name string branch/worktree name
---@param force? boolean use -D instead of -d
---@param cb? fun(ok: boolean)
function M.delete(name, force, cb)
  local flag = force and "-D" or "-d"
  M.run({ flag, "--nocd", name }, nil, function(stdout, stderr, code)
    if code ~= 0 then
      vim.notify("git-wt delete: " .. stderr, vim.log.levels.ERROR)
      if cb then cb(false) end
      return
    end
    if M.config.notify then
      vim.notify("git-wt: deleted " .. name)
    end
    if cb then cb(true) end
  end)
end

return M
