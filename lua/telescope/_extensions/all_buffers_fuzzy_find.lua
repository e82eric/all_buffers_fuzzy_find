local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local entry_display = require "telescope.pickers.entry_display"
local conf = require("telescope.config").values
local telescope = require('telescope')

local filter = vim.tbl_filter
local files = {}

files.all_buffers_fuzzy_find = function(opts)
  local lines_with_numbers = {}

  local bufnrs = filter(function(b)
  if 1 ~= vim.fn.buflisted(b) then
      return false
    end
    return true
  end, vim.api.nvim_list_bufs())

  for _, bufnr in ipairs(bufnrs) do
    local filename = vim.fn.expand(vim.api.nvim_buf_get_name(bufnr))
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for lnum, line in ipairs(lines) do
      table.insert(lines_with_numbers, {
        lnum = lnum,
        bufnr = bufnr,
        filename = filename,
        shortfilename = vim.fn.fnamemodify(filename, ':t'),
        text = line,
      })
    end
  end

  pickers.new(opts, {
    prompt_title = "Current Buffer Fuzzy",
    finder = finders.new_table {
      results = lines_with_numbers,
      entry_maker = opts.entry_maker or make_entry.gen_from_all_buffers_lines(opts),
    },
    sorter = conf.generic_sorter(opts),
    previewer = conf.grep_previewer(opts),
    attach_mappings = function()
      action_set.select:enhance {
        post = function()
          local selection = action_state.get_selected_entry()
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end,
      }

      return true
    end,
  }):find()
end

function make_entry.gen_from_all_buffers_lines(opts)
  local displayer = entry_display.create {
    separator = " │ ",
    items = {
      { width = 5 },
      { width = 25 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      { entry.lnum, opts.lnum_highlight_group or "TelescopeResultsSpecialComment" },
      { entry.shortfilename },
      {
        entry.text,
        function()
          if not opts.line_highlights then
            return {}
          end

          local line_hl = opts.line_highlights[entry.lnum] or {}
          -- TODO: We could probably squash these together if the are the same...
          --        But I don't think that it's worth it at the moment.
          local result = {}

          for col, hl in pairs(line_hl) do
            table.insert(result, { { col, col + 1 }, hl })
          end

          return result
        end,
      },
    }
  end

  return function(entry)
    if opts.skip_empty_lines and string.match(entry.text, "^$") then
      return
    end

    return {
      valid = true,
      ordinal = entry.text,
      display = make_display,
      filename = entry.filename,
      lnum = entry.lnum,
      text = entry.text,
			shortfilename = entry.shortfilename,
    }
  end
end

return telescope.register_extension {
  exports = { all_buffers_fuzzy_find = files.all_buffers_fuzzy_find }
}
