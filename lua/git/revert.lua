local utils = require "git.utils"
local git = require "git.utils.git"

local M = {}

local win, buf

local function create_revert_window()
  vim.api.nvim_command "new"
  win = vim.api.nvim_get_current_win()
  buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(buf, "buftype", "")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "buflisted", false)

  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "list", false)

  -- Keymaps
  local options = {
    noremap = true,
    silent = true,
    expr = false,
  }
  vim.api.nvim_buf_set_keymap(0, "n", "q", "<CMD>lua require('git.revert').close()<CR>", options)
  vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "<CMD>lua require('git.revert').revert()<CR>", options)
end

function M.close()
  if win then
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  win = nil

  if buf then
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  buf = nil
end

function M.open()
  local git_root, _ = git.get_repo_info()
  local git_log_cmd = "git -C "
    .. git_root
    .. ' --no-pager -c diff.context=0 -c diff.noprefix=false log --no-color --no-ext-diff --pretty="format:%H %s"'

  local function on_get_log_done(lines)
    if #lines <= 0 then
      return
    end

    create_revert_window()
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end

  utils.start_job(git_log_cmd, on_get_log_done)
end

function M.revert()
  local line = vim.api.nvim_get_current_line()
  if line == nil or line == "" then
    return
  end
  local commit_hash = utils.split(line, " ")[1]
  local git_root, _ = git.get_repo_info()
  local revert_cmd = "git -C " .. git_root .. " revert --no-commit " .. commit_hash

  git.run_git_cmd(revert_cmd)

  M.close()

  utils.log("Revert to commit " .. commit_hash)
end

return M
