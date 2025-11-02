local M = {}

--- Retrieve the name of the git branch, like 'master'
--- @return string | nil branch_name The name of the current branch, nil if not in a git repo
local function _get_git_branch_name()
	local handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
	if handle then
		local result = handle:read("*a")
		handle:close()
		-- Trim whitespace/newlines
		result = result:gsub("%s+", "")

		-- If they're not in a branch, return nil
		if result == "" or result == "HEAD" then
			return nil
		end

		-- Otherwise, return the branch name
		return result
	end

	-- If anything went wrong (like git not being executable)
	return nil
end

--- Get the name of the workspace. This is the final path portion of the PWD
--- @return string workspace_name The name of the current branch
local function _get_workspace_name()
	local pwd = vim.fn.getcwd()

	-- Get the final path portion
	return pwd:match("([^/]+)$")
end

--- Get the default scratch filename. Used when no name is provided for a scratch file
--- @param file_extension string The file extension to use for the file
--- @return string default_filename The default name of the file
local function _get_default_scratch_filename(file_extension)
	-- Get current date/time
	local timestamp = os.date("%Y-%m-%d-%H-%M")

	-- Generate random hash 8 character hash onto it, hopefully avoiding collisions
	local chars = "0123456789abcdef"
	local hash = {}
	for i = 1, 8 do
		local idx = math.random(1, #chars)
		hash[i] = chars:sub(idx, idx)
	end

	return timestamp .. "-" .. table.concat(hash) .. "." .. file_extension
end

--- List files with their last modified date
--- @param dir string The directory to iterate over
--- @return FileStatObject[] file_list A table containing the filenamn
local function _list_files_with_stat(dir)
	local files = {}
	local dir_iter = vim.uv.fs_scandir(dir)

	if not dir_iter then
		return files
	end

	while true do
		local name, _ = vim.uv.fs_scandir_next(dir_iter)
		if not name then
			break
		end

		local fullpath = dir .. "/" .. name
		local stat = vim.uv.fs_stat(fullpath)
		if stat and stat.mtime and stat.mtime.sec then
			table.insert(files, { filename = fullpath, mtime = stat.mtime.sec })
		end
	end

	return files
end

--- List files sorted by last modified (descending)
--- @param dir string The directory to iterate over
--- @return string[] file_list The files sorted by last modified (descending)
function M.get_files_sorted_by_mtime(dir)
	local files = _list_files_with_stat(dir)
	table.sort(files, function(a, b)
		return a.mtime > b.mtime
	end)

	local sorted_names = {}
	for _, f in ipairs(files) do
		table.insert(sorted_names, f.filename)
	end
	return sorted_names
end

--- Get the directory where scratch files should be stored/read from
--- @param scratch_root string The root of the scratch folder
function M.get_scratch_dir(scratch_root)
	local workspace_name = _get_workspace_name()
	local branch_name = _get_git_branch_name()
	local file_location = scratch_root .. "/" .. workspace_name .. "/"

	if branch_name ~= nil then
		file_location = file_location .. "/" .. branch_name .. "/"
	end

	vim.fn.mkdir(file_location, "p")
	return file_location
end

--- Make a default scratch file. This uses the default generated scratch filename
--- @param scratch_dir string The directory to put the newly generated scratch file in
--- @param file_extension? string The file extension to use. Only required if file_name isn't provided
--- @param file_name? string The name of the generated scratch file
--- @return string new_scratch_filepath The path to the newly created scratch file
function M.make_scratch_file(scratch_dir, file_extension, file_name)
	if file_name == nil then
		if file_extension ~= nil then
			file_name = _get_default_scratch_filename(file_extension)
		else
			error("Either `file_name` or `file_extension` must be provided!")
		end
	end

	local new_file_path = scratch_dir .. "/" .. file_name
	local f = io.open(new_file_path, "a")

	if f then
		f:close()
	else
		error("Could not open file: " .. new_file_path)
	end

	return new_file_path
end

--- Retrieve the latest scratch file, determined by modification time
--- If there is no "most recent" file to find, this function will generate one instead
--- @param scratch_root string The root of the scratch directory
--- @param default_file_extension string The file extension to create, if the file is auto-created
--- @return string scratch_file The last edited scratch file. If this doesn't exist, will generate one
function M.get_latest_scratch_file(scratch_root, default_file_extension)
	local scratch_dir = M.get_scratch_dir(scratch_root)
	local files_list = M.get_files_sorted_by_mtime(scratch_dir)

	-- If there aren't any files in there, make one
	if #files_list == 0 then
		return M.make_scratch_file(scratch_dir, default_file_extension)
	else
		return files_list[1]
	end
end

--- Retrieve the tmpdir for the OS.
--- This is the default scratch_root used in the config.
--- @return string tmpdir The OS' tmpdir.
function M.get_tmpdir()
	-- Attempt to detect the OS via looking at the FS seperators
	local sep = package.config:sub(1, 1)
	local is_windows = sep == "\\"

	-- Get envrionment variables, with plenty of fallbacks
	local env_vars
	if is_windows then
		env_vars = { "TMP", "TEMP", "USERPROFILE" }
	else
		env_vars = { "TMPDIR", "TMP", "TEMP" }
	end

	-- Keep trying until we get a hit
	for _, v in ipairs(env_vars) do
		local temp = os.getenv(v)
		if temp and temp ~= "" then
			return temp
		end
	end

	-- If we never got a hit, cross out fingers :)
	if is_windows then
		return "C:\\Windows\\Temp"
	else
		return "/tmp"
	end
end

return M
