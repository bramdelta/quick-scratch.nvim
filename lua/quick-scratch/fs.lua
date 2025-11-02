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
	local pwd = io.popen("pwd"):read("*l")

	-- Get the final path portion
	return pwd:match("([^/]+)$")
end

--- Get the default scratch filename. Used when no name is provided for a scratch file
--- @param file_extension string The file extension to use for the file.
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
	-- Use %Y for mtime seconds, %n for filename
	local cmd = string.format("stat --format '%%Y %%n' %s/*", dir)
	local p = io.popen(cmd)
	if p then
		for line in p:lines() do
			local mtime, filename = line:match("^(%d+)%s(.+)$")
			if mtime and filename then
				table.insert(files, { filename = filename, mtime = tonumber(mtime) })
			end
		end
		p:close()
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
--- @return string scratch_file The last edited scratch file. If this doesn't exist, will generate one
function M.get_latest_scratch_file(scratch_root)
	local scratch_dir = M.get_scratch_dir(scratch_root)
	local files_list = M.get_files_sorted_by_mtime(scratch_dir)

	-- If there aren't any files in there, make one
	if #files_list == 0 then
		return M.make_scratch_file(scratch_dir)
	else
		return files_list[1]
	end
end

return M
