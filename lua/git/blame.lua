local M = {}

local function blameLinechars()
  local chars = vim.fn.strlen(
    vim.fn.substitute(vim.fn.matchstr(vim.fn.getline ".", [[.\{-\}\s\+\d\+\ze)]]), [[\v\C.]], ".", "g")
  )
  if vim.fn.exists "*synconcealed" and vim.wo.conceallevel > 1 then
    for col = 1, chars do
      chars = chars - vim.fn.synconcealed(vim.fn.line ".", col)[0]
    end
  end

  return chars
end

local function create_blame_win()
  vim.api.nvim_command "topleft vnew"
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "git.nvim")
  vim.api.nvim_buf_set_option(buf, "buflisted", false)

  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "cursorbind", true)
  vim.api.nvim_win_set_option(win, "scrollbind", true)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "foldcolumn", "0")
  vim.api.nvim_win_set_option(win, "foldenable", false)
  vim.api.nvim_win_set_option(win, "foldenable", false)
  vim.api.nvim_win_set_option(win, "winfixwidth", true)
  vim.api.nvim_win_set_option(win, "signcolumn", "no")

  return win, buf
end

local function on_blame_done(lines)
  local starting_win = vim.api.nvim_get_current_win()
  local current_pos = vim.api.nvim_win_get_cursor(starting_win)
  local blame_win, blame_buf = create_blame_win()

  vim.api.nvim_buf_set_lines(blame_buf, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(blame_buf, "modifiable", false)
  vim.api.nvim_win_set_width(blame_win, blameLinechars() + 1)
  vim.api.nvim_win_set_cursor(blame_win, current_pos)
  -- TODO: Restore these options when blame windown is closed
  vim.api.nvim_win_set_option(starting_win, "scrollbind", true)
  vim.api.nvim_win_set_option(starting_win, "cursorbind", true)

  -- Keymaps
  local options = {
    noremap = true,
    silent = true,
    expr = false,
  }

  vim.api.nvim_buf_set_keymap(0, "n", "q", "<CMD>q<CR>", options)
  vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "<CMD>lua require('git.blame').blame_commit()<CR>", options)
end

function M.blame_commit()
  vim.notify "TBD"
end

function M.blame()
  local fpath = vim.fn.expand "%:p"
  if fpath == "" or fpath == nil then
    return
  end

  local blame_cmd = "git --literal-pathspecs --no-pager -c blame.coloring=none -c blame.blankBoundary=false blame --show-number -- "
    .. fpath

  local lines = {}

  local function on_event(_, data, event)
    if event == "stdout" or event == "stderr" then
      if data then
        for i = 1, #data do
          if data[i] ~= "" then
            table.insert(lines, data[i])
          end
        end
      end
    end

    if event == "exit" then
      on_blame_done(lines)
    end
  end

  vim.fn.jobstart(blame_cmd, {
    on_stderr = on_event,
    on_stdout = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
  })
end

return M