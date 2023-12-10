require('dap-python').setup()
require("nvim-dap-virtual-text").setup {
	enabled = true,
	highlight_changed_variables = true,    -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
	highlight_new_as_changed = true,      -- highlight new variables in the same way as changed variables (if highlight_changed_variables)
	show_stop_reason = true,               -- show stop reason when stopped for exceptions
	only_first_definition = false,          -- only show virtual text at first definition (if there are multiple)
	all_references = true,                -- show virtual text on all all references of the variable (not only definitions)
	all_frames = true,                    -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
}

local dap = require("dap")
local dapui = require("dapui")

dapui.setup()

dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
vim.api.nvim_create_user_command('Closedapui',function() dapui.close() end,{})
vim.api.nvim_create_user_command('Opendapui',function() dapui.open() end,{})
vim.api.nvim_create_user_command('Toggledapui',function() dapui.toggle() end,{})
vim.api.nvim_create_user_command('Clearbreakpoints',function() dap.clear_breakpoints() end,{})


local programName = vim.fn.getcwd() .. "/"
local argument_string = ' '
local alreadySetup = false

function startDebugger()
	local filetype = vim.bo.filetype
	if filetype ~= "c" and filetype ~= "cpp" then return 0 end
	local programNameaux = vim.fn.input('Path to executable: ', programName , "file")
	if programNameaux ~= '' then
		programName = programNameaux
	else
		return 0
	end
	local argument_stringaux = vim.fn.input('Program arguments: ', argument_string)
	if argument_stringaux ~= '' then
		argument_string = argument_stringaux
	end
	if vim.fn.input('Continue to debugger?(y/n): ', 'y') == 'y' then
		return 1
	end 
	return 0
end

local compDeb = 'make'
vim.keymap.set('n', '<A-d>', function()
	local filetype = vim.bo.filetype
	if filetype ~= "c" and filetype ~= "cpp" and filetype ~= "rust" then print("Not c/c++ project!") return end
	compDebaux = vim.fn.input('Compile to debug: ', compDeb)
	if compDebaux ~= '' then
		compDeb = compDebaux
		vim.cmd("!" .. compDeb)
	end
	if (vim.api.nvim_eval("v:shell_error") ~= 0) then
		print("Compile error!")
		return
	end
	if startDebugger() == 1 then 
		alreadySetup = true
		dap.continue()
	end
end, opts)

vim.keymap.set('n', '<A-e>', function()
	local filetype = vim.bo.filetype
	if filetype ~= "c" and filetype ~= "cpp" and filetype ~= "rust" then print("Not c/c++ project!") return end
	if alreadySetup == false then print("Debug not configured!") return end
	vim.cmd("!" .. compDeb)
	if vim.api.nvim_eval("v:shell_error") ~= 0 then return end
	dap.continue()
end, opts)

dap.adapters.codelldb = {
	type = 'server',
	port = "${port}",
	executable = {
		command =vim.fn.stdpath("data") .. '/mason/bin/codelldb',
		args = {"--port", "${port}"},
	},
}

dap.configurations.c = {
	{
		name = "Launch with LLDB",
		type = "codelldb",
		request = "launch",
		program =function() return  programName end,
		cwd = '${workspaceFolder}',
		stopOnEntry = false,
		args = function() return vim.fn.split(argument_string) end,
		showDisassembly = "never"
	},
}
dap.configurations.cpp = dap.configurations.c
dap.configurations.rust = dap.configurations.c
