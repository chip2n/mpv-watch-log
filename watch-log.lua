watched_positions = {}
start_pos = 0
curr_pos = 0
file_path = nil
file_path_hash = nil

local o = {
    storage = "~/.config/mpv/watch-log/",
}

opt = require "mp.options"
opt.read_options(o, "watch-log")

o.storage = mp.command_native({"expand-path", o.storage})

function hash(str)
    local pipe = io.popen('echo -n "' .. str .. '" | md5sum')
    local result = pipe:read("*all")
    pipe:close()
    return result:match("%S+")
end

function add_watched(start_pos, end_pos)
   table.insert(watched_positions, {start_pos, end_pos})
   merge_intervals()
end

function merge_intervals()
  table.sort(watched_positions, function(a, b) return a[1] < b[1] end)

  local i = 1
  while i < #watched_positions do
    if watched_positions[i][2] >= watched_positions[i+1][1] then
      watched_positions[i][2] = math.max(watched_positions[i][2], watched_positions[i+1][2])
      table.remove(watched_positions, i+1)
    else
      i = i + 1
    end
  end
end

function on_file_loaded()
   local pos = mp.get_property_number("time-pos")
   start_pos = pos
   curr_pos = pos
   file_path = mp.get_property("path")
   file_path_hash = hash(file_path)

   local f = io.open(o.storage .. file_path_hash, "r")
   if f == nil then return end

   local contents = f:read("*a")
   f:close()

   for s in contents:gmatch("[^\r\n]+") do
      local nums = {}
      for n in s:gmatch("%S+") do table.insert(nums, n) end
      add_watched(tonumber(nums[1]), tonumber(nums[2]))
   end

   -- Go to the earliest end point in the log
   if next(watched_positions) ~= nil then
      local first = watched_positions[1]
      mp.set_property_number("time-pos", first[2])
   end
end

function on_end_file()
   add_watched(start_pos, curr_pos)

   os.execute(string.format("mkdir -p %s", o.storage))
   local h = assert(io.open(o.storage .. file_path_hash, "w"))

   for _, entry in ipairs(watched_positions) do
      h:write(entry[1] .. " " .. entry[2] .. "\n")
   end

   h:close()
end

function on_tick()
   local pos = mp.get_property_number("time-pos")
   if pos then
      if math.abs(pos - curr_pos) > 1 then
         print("jump: " .. curr_pos .. " -> " .. pos)
         add_watched(start_pos, curr_pos)
         start_pos = pos
      end
      curr_pos = pos
   end
end

mp.register_event("file-loaded", on_file_loaded)
mp.register_event("end-file", on_end_file)
mp.register_event("tick", on_tick)
