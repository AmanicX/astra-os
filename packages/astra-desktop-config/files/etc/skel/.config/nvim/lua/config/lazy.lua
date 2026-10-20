-- AstraOS Neovim bootstrap.
--
-- The ISO and the installed system ship a pinned, read-only plugin tree at
-- /usr/share/astra/nvim/lazy. LazyVim writes lockfiles, compiled parsers and
-- state into the plugin root, so the tree is copied into the user's writable
-- data directory on first launch. No network clone is attempted at startup.
local system_root = "/usr/share/astra/nvim/lazy"
local lazy_root = vim.env.ASTRA_NVIM_LAZY or (vim.fn.stdpath("data") .. "/lazy")
local lazypath = lazy_root .. "/lazy.nvim"

local function exists(path)
	return (vim.uv or vim.loop).fs_stat(path) ~= nil
end

if not exists(lazypath) and lazy_root ~= system_root and exists(system_root .. "/lazy.nvim") then
	vim.fn.mkdir(lazy_root, "p")
	local result = vim.fn.system({ "cp", "-a", system_root .. "/.", lazy_root .. "/" })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "AstraOS: could not seed the Neovim plugin tree.\n", "ErrorMsg" },
			{ result, "WarningMsg" },
		}, true, {})
	end
end

if not exists(lazypath) then
	vim.api.nvim_echo({
		{ "AstraOS: the Neovim plugin tree is missing.\n", "ErrorMsg" },
		{ "Install astra-desktop-config or rerun scripts/prebake-nvim.sh.\n", "WarningMsg" },
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
