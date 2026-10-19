-- Install in ~/.config/nvim/lua/plugins/kitty-theme.lua (LazyVim).
-- Read the same generated palette as Kitty; no second theme generator needed.
local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local palette_path = config_home .. "/kitty/themes/noctalia.conf"
local last_palette = nil

local function transparent_ui()
  for _, name in ipairs({
    "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn",
    "FoldColumn", "EndOfBuffer", "LineNr", "CursorLineNr", "MsgArea",
    "WinSeparator", "StatusLine", "StatusLineNC", "TabLine", "TabLineFill",
    "Pmenu", "PmenuSbar", "NeoTreeNormal", "NeoTreeNormalNC",
    "NeoTreeEndOfBuffer", "NeoTreeFloatBorder", "TelescopeNormal",
    "TelescopeBorder", "TelescopePromptNormal", "TelescopeResultsNormal",
    "TelescopePreviewNormal", "SnacksNormal", "SnacksNormalNC",
    "SnacksDashboardNormal", "SnacksPicker", "SnacksPickerBorder",
    "SnacksPickerInput", "SnacksPickerList", "SnacksPickerPreview",
    "SnacksPickerTitle", "SnacksInputNormal", "BlinkCmpMenu",
    "BlinkCmpMenuBorder", "BlinkCmpDoc", "BlinkCmpDocBorder",
    "WhichKeyNormal", "WhichKeyBorder", "LazyNormal", "MasonNormal",
  }) do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    hl.bg = nil
    hl.ctermbg = nil
    vim.api.nvim_set_hl(0, name, hl)
  end
  -- Keep selection/search/diff backgrounds: they carry useful meaning.
end

local function apply_palette(force)
  local lines = {}
  if vim.fn.filereadable(palette_path) == 1 then
    lines = vim.fn.readfile(palette_path)
  end
  local signature = table.concat(lines, "\n")
  if not force and signature == last_palette then return end
  last_palette = signature
  local c = {}
  for _, line in ipairs(lines) do
    local key, value = line:match("^%s*([%w_]+)%s+(#%x%x%x%x%x%x)%s*$")
    if key then c[key] = value end
  end
  -- Fallback only until Noctalia generates its Kitty palette.
  local bg, fg = c.background or "#070722", c.foreground or "#e8e8ee"
  require("base16-colorscheme").setup({
    base00 = bg,
    base01 = c.color0 or bg,
    base02 = c.color8 or "#454559",
    base03 = c.color8 or "#888899",
    base04 = c.color7 or fg,
    base05 = fg,
    base06 = c.color15 or fg,
    base07 = c.color15 or fg,
    base08 = c.color1 or "#fd4663",
    base09 = c.color9 or "#ff9966",
    base0A = c.color3 or "#fff59b",
    base0B = c.color2 or "#b5d99c",
    base0C = c.color6 or "#8bd5ca",
    base0D = c.color4 or "#8aadf4",
    base0E = c.color5 or "#c6a0f6",
    base0F = c.color13 or "#f5bde6",
  })
  transparent_ui()
end

return {
  { "RRethy/base16-nvim", lazy = true },
  {
    "LazyVim/LazyVim",
    dependencies = { "RRethy/base16-nvim" },
    opts = {
      colorscheme = function() apply_palette(true) end,
    },
    init = function()
      local group = vim.api.nvim_create_augroup("KittyNoctaliaTheme", { clear = true })
      vim.api.nvim_create_autocmd("FocusGained", {
        group = group,
        callback = function() apply_palette(false) end,
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function() vim.schedule(transparent_ui) end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "LazyLoad",
        callback = function() vim.schedule(transparent_ui) end,
      })
      vim.api.nvim_create_user_command("KittyThemeReload", function()
        apply_palette(true)
      end, { desc = "Reload Noctalia's Kitty palette" })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local fg = normal.fg and string.format("#%06x", normal.fg) or "#e8e8ee"
      local section = { a = { fg = fg, bg = "NONE", gui = "bold" }, b = { fg = fg, bg = "NONE" }, c = { fg = fg, bg = "NONE" } }
      opts.options.theme = {
        normal = vim.deepcopy(section), insert = vim.deepcopy(section),
        visual = vim.deepcopy(section), replace = vim.deepcopy(section),
        command = vim.deepcopy(section), inactive = vim.deepcopy(section),
      }
    end,
  },
}
