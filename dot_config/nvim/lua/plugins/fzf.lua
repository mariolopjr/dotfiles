---@type table<string, string[]|boolean>?
local kind_filter = {
  default = {
    "Class",
    "Constructor",
    "Enum",
    "Field",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    "Package",
    "Property",
    "Struct",
    "Trait",
  },
  markdown = false,
  help = false,
  -- you can specify a different filter for each filetype
  lua = {
    "Class",
    "Constructor",
    "Enum",
    "Field",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    -- "Package", -- remove package since luals uses it for control flow structures
    "Property",
    "Struct",
    "Trait",
  },
}

---@param buf? number
---@return string[]?
local function get_kind_filter(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local ft = vim.bo[buf].filetype
  if kind_filter == false then
    return
  end
  if kind_filter == nil then
    return
  end
  if kind_filter[ft] == false then
    return
  end
  if type(kind_filter[ft]) == "table" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return kind_filter[ft]
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return type(kind_filter) == "table"
      and type(kind_filter.default) == "table"
      and kind_filter.default
    or nil
end

local function symbols_filter(entry, ctx)
  if ctx.symbols_filter == nil then
    ctx.symbols_filter = get_kind_filter(ctx.bufnr) or false
  end
  if ctx.symbols_filter == false then
    return true
  end
  return vim.tbl_contains(ctx.symbols_filter, entry.kind)
end

local picker_commands = {
  files = "files",
}

---@param command? string
---@param opts? table
local function picker_open(command, opts)
  command = command ~= "auto" and command or "files"
  opts = opts or {}

  opts = vim.deepcopy(opts)

  if type(opts.cwd) == "boolean" then
    vim.notify("picker: opts.cwd should be a string or nil")
    opts.cwd = nil
  end

  -- if not opts.cwd and opts.root ~= false then
  --   opts.cwd = LazyVim.root({ buf = opts.buf })
  -- end

  command = picker_commands[command] or command

  if opts.cmd == nil and command == "git_files" and opts.show_untracked then
    opts.cmd = "git ls-files --exclude-standard --cached --others"
  end

  return require("fzf-lua")[command](opts)
end

---@param opts? lsp.Client.filter
local function get_clients(opts)
  local ret = {} ---@type vim.lsp.Client[]
  if vim.lsp.get_clients then
    ret = vim.lsp.get_clients(opts)
  else
    ---@diagnostic disable-next-line: deprecated
    ret = vim.lsp.get_active_clients(opts)
    if opts and opts.method then
      ---@param client vim.lsp.Client
      ret = vim.tbl_filter(function(client)
        return client.supports_method(opts.method, { bufnr = opts.bufnr })
      end, ret)
    end
  end
  return opts and opts.filter and vim.tbl_filter(opts.filter, ret) or ret
end

return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    opts = function(_, _)
      local fzf = require("fzf-lua")
      local config = fzf.config
      local actions = fzf.actions

      -- Quickfix
      config.defaults.keymap.fzf["ctrl-q"] = "select-all+accept"
      config.defaults.keymap.fzf["ctrl-u"] = "half-page-up"
      config.defaults.keymap.fzf["ctrl-d"] = "half-page-down"
      config.defaults.keymap.fzf["ctrl-x"] = "jump"
      config.defaults.keymap.fzf["ctrl-f"] = "preview-page-down"
      config.defaults.keymap.fzf["ctrl-b"] = "preview-page-up"
      config.defaults.keymap.builtin["<c-f>"] = "preview-page-down"
      config.defaults.keymap.builtin["<c-b>"] = "preview-page-up"

      -- Trouble
      config.defaults.actions.files["ctrl-t"] = require("trouble.sources.fzf").actions.open

      -- Toggle root dir / cwd
      config.defaults.actions.files["ctrl-r"] = function(_, ctx)
        local o = vim.deepcopy(ctx.__call_opts)
        o.root = o.root == false
        o.cwd = nil
        o.buf = ctx.__CTX.bufnr
        picker_open(ctx.__INFO.cmd, o)
      end
      config.defaults.actions.files["alt-c"] = config.defaults.actions.files["ctrl-r"]
      config.set_action_helpstr(config.defaults.actions.files["ctrl-r"], "toggle-root-dir")

      return {
        "default-title",
        fzf_colors = true,
        fzf_opts = {
          ["--no-scrollbar"] = true,
        },
        defaults = {
          -- formatter = "path.filename_first",
          formatter = "path.dirname_first",
        },
        -- Custom LazyVim option to configure vim.ui.select
        ui_select = function(fzf_opts, items)
          return vim.tbl_deep_extend("force", fzf_opts, {
            prompt = " ",
            winopts = {
              title = " " .. vim.trim((fzf_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " ",
              title_pos = "center",
            },
          }, fzf_opts.kind == "codeaction" and {
            winopts = {
              layout = "vertical",
              -- height is number of items minus 15 lines for the preview, with a max of 80% screen height
              height = math.floor(math.min(vim.o.lines * 0.8 - 16, #items + 2) + 0.5) + 16,
              width = 0.5,
              preview = not vim.tbl_isempty(get_clients({ bufnr = 0, name = "vtsls" })) and {
                layout = "vertical",
                vertical = "down:15,border-top",
                hidden = "hidden",
              } or {
                layout = "vertical",
                vertical = "down:15,border-top",
              },
            },
          } or {
            winopts = {
              width = 0.5,
              -- height is number of items, with a max of 80% screen height
              height = math.floor(math.min(vim.o.lines * 0.8, #items + 2) + 0.5),
            },
          })
        end,
        winopts = {
          width = 0.8,
          height = 0.8,
          row = 0.5,
          col = 0.5,
          preview = {
            scrollchars = { "┃", "" },
          },
        },
        files = {
          cwd_prompt = false,
          actions = {
            ["alt-i"] = { actions.toggle_ignore },
            ["alt-h"] = { actions.toggle_hidden },
          },
        },
        grep = {
          actions = {
            ["alt-i"] = { actions.toggle_ignore },
            ["alt-h"] = { actions.toggle_hidden },
          },
        },
        lsp = {
          symbols = {
            symbol_hl = function(s)
              return "TroubleIcon" .. s
            end,
            symbol_fmt = function(s)
              return s:lower() .. "\t"
            end,
            child_prefix = false,
          },
          code_actions = {
            previewer = vim.fn.executable("delta") == 1 and "codeaction_native" or nil,
          },
        },
      }
    end,
    config = function(_, opts)
      if opts[1] == "default-title" then
        -- use the same prompt for all pickers for profile `default-title` and
        -- profiles that use `default-title` as base profile
        local function fix(t)
          t.prompt = t.prompt ~= nil and " " or nil
          for _, v in pairs(t) do
            if type(v) == "table" then
              fix(v)
            end
          end
          return t
        end
        opts = vim.tbl_deep_extend("force", fix(require("fzf-lua.profiles.default-title")), opts)
        opts[1] = nil
      end
      require("fzf-lua").setup(opts)
    end,
    keys = {
      { "<c-j>", "<c-j>", ft = "fzf", mode = "t", nowait = true },
      { "<c-k>", "<c-k>", ft = "fzf", mode = "t", nowait = true },
      {
        "<leader>,",
        "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>",
        desc = "Switch Buffer",
      },
      {
        "<leader>/",
        function()
          picker_open("live_grep")
        end,
        desc = "Grep (Root Dir)",
      },
      { "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
      -- find
      {
        "<leader>fb",
        "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>",
        desc = "Buffers",
      },
      {
        "<leader>fc",
        function()
          picker_open("files", { cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find Config File",
      },
      {
        "<leader>ff",
        function()
          picker_open("files")
        end,
        desc = "Find Files (Root Dir)",
      },
      {
        "<leader>fF",
        function()
          picker_open("files", { root = false })
        end,
        desc = "Find Files (cwd)",
      },
      { "<leader>fg", "<cmd>FzfLua git_files<cr>", desc = "Find Files (git-files)" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent" },
      {
        "<leader>fR",
        function()
          picker_open("oldfiles", { cwd = vim.uv.cwd() })
        end,
        desc = "Recent (cwd)",
      },
      -- git
      { "<leader>gc", "<cmd>FzfLua git_commits<CR>", desc = "Commits" },
      { "<leader>gs", "<cmd>FzfLua git_status<CR>", desc = "Status" },
      -- search
      { '<leader>s"', "<cmd>FzfLua registers<cr>", desc = "Registers" },
      { "<leader>sa", "<cmd>FzfLua autocmds<cr>", desc = "Auto Commands" },
      { "<leader>sb", "<cmd>FzfLua grep_curbuf<cr>", desc = "Buffer" },
      { "<leader>sc", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
      { "<leader>sC", "<cmd>FzfLua commands<cr>", desc = "Commands" },
      { "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Document Diagnostics" },
      { "<leader>sD", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace Diagnostics" },
      {
        "<leader>sg",
        function()
          picker_open("live_grep")
        end,
        desc = "Grep (Root Dir)",
      },
      {
        "<leader>sG",
        function()
          picker_open("live_grep", { root = false })
        end,
        desc = "Grep (cwd)",
      },
      { "<leader>sh", "<cmd>FzfLua help_tags<cr>", desc = "Help Pages" },
      { "<leader>sH", "<cmd>FzfLua highlights<cr>", desc = "Search Highlight Groups" },
      { "<leader>sj", "<cmd>FzfLua jumps<cr>", desc = "Jumplist" },
      { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Key Maps" },
      { "<leader>sl", "<cmd>FzfLua loclist<cr>", desc = "Location List" },
      { "<leader>sM", "<cmd>FzfLua man_pages<cr>", desc = "Man Pages" },
      { "<leader>sm", "<cmd>FzfLua marks<cr>", desc = "Jump to Mark" },
      { "<leader>sR", "<cmd>FzfLua resume<cr>", desc = "Resume" },
      { "<leader>sq", "<cmd>FzfLua quickfix<cr>", desc = "Quickfix List" },
      {
        "<leader>sw",
        function()
          picker_open("grep_cword")
        end,
        desc = "Word (Root Dir)",
      },
      {
        "<leader>sW",
        function()
          picker_open("grep_cword", { root = false })
        end,
        desc = "Word (cwd)",
      },
      {
        "<leader>sw",
        function()
          picker_open("grep_visual")
        end,
        mode = "v",
        desc = "Selection (Root Dir)",
      },
      {
        "<leader>sW",
        function()
          picker_open("grep_visual", { root = false })
        end,
        mode = "v",
        desc = "Selection (cwd)",
      },
      {
        "<leader>uC",
        function()
          picker_open("colorschemes")
        end,
        desc = "Colorscheme with Preview",
      },
      {
        "<leader>ss",
        function()
          require("fzf-lua").lsp_document_symbols({
            regex_filter = symbols_filter,
          })
        end,
        desc = "Goto Symbol",
      },
      {
        "<leader>sS",
        function()
          require("fzf-lua").lsp_live_workspace_symbols({
            regex_filter = symbols_filter,
          })
        end,
        desc = "Goto Symbol (Workspace)",
      },
    },
  },
}
