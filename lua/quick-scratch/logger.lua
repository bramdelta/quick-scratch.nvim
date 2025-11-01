--- @alias logging_levels 'DEBUG' | 'OFF' The available logging levels

--- @class Logger
--- @field level logging_levels The level of which to log
--- @field logfile string The path to where the logger should store its logs
local Logger = {}
Logger.__index = Logger

-- Initialize logger
--- @return self logger An instance of the logger
function Logger:new()
	local obj = setmetatable({}, self)
	obj.logfile = vim.fn.stdpath("cache") .. "/scratch-buffers.log"
	obj.level = "DEBUG"
	return obj
end

--- Helper function for producing timestamps
--- @return string timestamp The timestamp.
function Logger:timestamp()
	return tostring(os.date("%Y-%m-%d %H:%M:%S"))
end

--- Append a line with timestamp to the file
--- @param msg string The message to log
function Logger:log(msg)
	if self.level == "OFF" then
		return
	end

	local line = string.format("[%s] %s\n", self:timestamp(), msg)
	local f = io.open(self.logfile, "a")
	if f then
		f:write(line)
		f:close()
	else
		vim.notify("Failed to open log file: " .. self.logfile, vim.log.levels.ERROR)
	end
end

--- Set the logger's logging level
--- @param log_level logging_levels The level to set the logger to
function Logger:set_level(log_level)
	self.level = log_level
end

return Logger
