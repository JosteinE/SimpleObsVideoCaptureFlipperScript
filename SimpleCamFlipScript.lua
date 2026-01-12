obs = obslua

local selected_source = nil

local hotkey_h_id = obs.OBS_INVALID_HOTKEY_ID
local hotkey_h_name = "ToggleHorizontalFlip"

local hotkey_v_id = obs.OBS_INVALID_HOTKEY_ID
local hotkey_v_name = "ToggleVerticalFlip"


local Alignment = {
	CENTER = 0,
	CENTER_LEFT = 1,
	CENTER_RIGHT = 2,
	TOP_CENTER = 4,
	TOP_LEFT = 5,
	TOP_RIGHT = 6,
	BOTTOM_CENTER = 8,
	BOTTOM_LEFT = 9,
	BOTTOM_RIGHT = 10
}

-- Helper: compute visible dimensions (crop + scale aware)
local function get_visible_dimensions(item)
	local crop = obs.obs_sceneitem_crop()
	obs.obs_sceneitem_get_crop(item, crop)

	local scale = obs.vec2()
	obs.obs_sceneitem_get_scale(item, scale)

	local src = obs.obs_sceneitem_get_source(item)
	local sw = obs.obs_source_get_width(src)
	local sh = obs.obs_source_get_height(src)

	local cropped_width  = sw - crop.left - crop.right
	local cropped_height = sh - crop.top - crop.bottom

	local visible_width  = cropped_width  * math.abs(scale.x)
	local visible_height = cropped_height * math.abs(scale.y)

	return visible_width, visible_height, scale
end

local function alignment_offset(a, width, height)
	if a == Alignment.CENTER then return 0, 0
	elseif a == Alignment.CENTER_LEFT then return -width, 0
	elseif a == Alignment.CENTER_RIGHT then return width, 0
	elseif a == Alignment.TOP_CENTER then return 0, -height
	elseif a == Alignment.TOP_LEFT then return -width, -height
	elseif a == Alignment.TOP_RIGHT then return width, -height
	elseif a == Alignment.BOTTOM_CENTER then return 0, height
	elseif a == Alignment.BOTTOM_LEFT then return -width, height
	elseif a == Alignment.BOTTOM_RIGHT then return width, height
	else return 0, 0
	end
end

-- Applies flip selected source in all scenes
local function toggle_flip(do_h, do_v)
	if not selected_source or selected_source == "" then
		return
	end

	local scenes = obs.obs_frontend_get_scenes()
	if not scenes then return end
	
	for _, scene in ipairs(scenes) do
		local scene_source = obs.obs_scene_from_source(scene)
		if scene_source then
			local item = obs.obs_scene_find_source(scene_source, selected_source)
			if item then
				-- Get transformed scale
				local visible_width, visible_height, scale = get_visible_dimensions(item)
				
				-- Get offset vector to compensate for non-centered positional alignments 
				local alignment = obs.obs_sceneitem_get_alignment(item)
				local offset_x, offset_y = alignment_offset(alignment, visible_width, visible_height)
				local pos = obs.vec2()
				obs.obs_sceneitem_get_pos(item, pos)
				
				local has_bounds = obs.obs_sceneitem_get_bounds_type(item) ~= 0
				
				-- Horizontal flip and correction
				if do_h then 
					scale.x = -scale.x 
					
					if not has_bounds then
						if scale.x < 0 then pos.x = pos.x - offset_x
						else pos.x = pos.x + offset_x end
					end
				end

				-- Vertical flip and correction
				if do_v then
					scale.y = -scale.y
					
					if not has_bounds then
						if scale.y < 0 then pos.y = pos.y - offset_y
						else pos.y = pos.y + offset_y end
					end
				end
				
				obs.obs_sceneitem_set_scale(item, scale)
				obs.obs_sceneitem_set_pos(item, pos)
			end
		end
	end

	obs.source_list_release(scenes)
end

-- Hotkey bindings
local function flip_horizontal_pressed(pressed)
	if pressed then
		toggle_flip(true, false)
	end
end

local function flip_vertical_pressed(pressed)
	if pressed then
		toggle_flip(false, true)
	end
end

-- UI Dropdown for source selection
function script_properties()
	local props = obs.obs_properties_create()

	local p = obs.obs_properties_add_list(
		props,
		"selected_source",
		"Camera Source",
		obs.OBS_COMBO_TYPE_LIST,
		obs.OBS_COMBO_FORMAT_STRING
	)

	-- Populate with all video capture sources
	local sources = obs.obs_enum_sources()
	if sources then
		for _, src in ipairs(sources) do
			local id = obs.obs_source_get_id(src)
			if id == "dshow_input" or id == "av_capture_input" or id == "v4l2_input" then
				local name = obs.obs_source_get_name(src)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
		obs.source_list_release(sources)
	end

	return props
end

-- Settings persistence
function script_update(settings)
	selected_source = obs.obs_data_get_string(settings, "selected_source")
end

function script_load(settings)
	selected_source = obs.obs_data_get_string(settings, "selected_source")

	hotkey_h_id = obs.obs_hotkey_register_frontend(
		hotkey_h_name,
		"Toggle Horizontal Flip",
		flip_horizontal_pressed
	)

	hotkey_v_id = obs.obs_hotkey_register_frontend(
		hotkey_v_name,
		"Toggle Vertical Flip",
		flip_vertical_pressed
	)

	local arr_h = obs.obs_data_get_array(settings, hotkey_h_name)
	obs.obs_hotkey_load(hotkey_h_id, arr_h)
	obs.obs_data_array_release(arr_h)

	local arr_v = obs.obs_data_get_array(settings, hotkey_v_name)
	obs.obs_hotkey_load(hotkey_v_id, arr_v)
	obs.obs_data_array_release(arr_v)
end

function script_save(settings)
	obs.obs_data_set_string(settings, "selected_source", selected_source)

	local arr_h = obs.obs_hotkey_save(hotkey_h_id)
	obs.obs_data_set_array(settings, hotkey_h_name, arr_h)
	obs.obs_data_array_release(arr_h)

	local arr_v = obs.obs_hotkey_save(hotkey_v_id)
	obs.obs_data_set_array(settings, hotkey_v_name, arr_v)
	obs.obs_data_array_release(arr_v)
end

function script_description()
	return "Flip selected video capture source in all scenes via hotkeys."
end
