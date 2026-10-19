-- AstraOS offline Neovim bootstrap.
--
-- The ISO ships a read-only plugin tree at /usr/share/astra/nvim/lazy. If it
-- is absent (for example on a developer machine), fall back to the normal
-- per-user data directory. No network clone is attempted at startup.
local lazy_root = vim.env.ASTRA_NVIM_LAZY or "/usr/share/astra/nvim/lazy"
local lazypath = lazy_root .. "/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  lazy_root = vim.fn.stdpath("data") .. "/lazy"
  lazypath = lazy_root .. "/lazy.nvim"
end

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.api.nvim_echo({
    { "AstraOS: the Neovim plugin tree is missing.\n", "ErrorMsg" },
    { "Reinstall astra-desktop-config or run the ISO pre-bake step.\n", "WarningMsg" },
    { "\nPress any key to exit...", "WarningMsg" },
  }, true, {})
  vim.fn.getchar()
  os.exit(1)
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  root = lazy_root,
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = false, -- offline-first; do not check for plugin updates
    notify = false,
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
