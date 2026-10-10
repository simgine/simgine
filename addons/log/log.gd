@tool
class_name Log
extends Object

enum Level {
	OFF,
	ERROR,
	WARN,
	INFO,
	DEBUG,
	TRACE,
}

static var settings: Settings = _get_settings()


static func _get_settings() -> Settings:
	var env_filters := OS.get_environment("GODOT_LOG")
	if env_filters:
		return Settings.new(env_filters)

	var project_filters: String = ProjectSettings.get_setting(
		LogPlugin.FILTERS_SETTING,
		LogPlugin.DEFAULT_FILTERS,
	)
	return Settings.new(project_filters)


static func error(format: String, ...args: Array) -> void:
	_log(Level.ERROR, format, args)


static func warn(format: String, ...args: Array) -> void:
	_log(Level.WARN, format, args)


static func info(format: String, ...args: Array) -> void:
	_log(Level.INFO, format, args)


static func debug(format: String, ...args: Array) -> void:
	_log(Level.DEBUG, format, args)


static func trace(format: String, ...args: Array) -> void:
	_log(Level.TRACE, format, args)


static func _log(level: Level, format: String, args: Array) -> void:
	if settings.default_level < level and settings.filters.is_empty():
		# Return early if possible to avoid inspecting the stack.
		return

	var caller := _get_caller()
	var source: String = caller.get("source", "")
	source = source.trim_prefix("res://")
	if settings.resolve_level(source) < level:
		return

	var time := Time.get_time_string_from_system()
	var level_str: String = Level.find_key(level)
	var user_msg := format if args.is_empty() else format % args

	var msg: String
	if source:
		msg = "[%s %s %s:%d] %s" % [time, level_str, source, caller.line, user_msg]
	else:
		msg = "[%s %s] %s" % [time, level_str, user_msg]

	match level:
		Level.ERROR:
			push_error(msg)
		Level.WARN:
			push_warning(msg)
		_:
			print(msg)


static func _get_caller() -> Dictionary:
	# 0 = _get_caller()
	# 1 = _log()
	# 2 = info()/debug()/warn()/etc.
	# 3 = actual caller
	var stack := get_stack()
	if stack.size() <= 3:
		return { }

	return stack[3]


class Settings:
	var default_level := Level.DEBUG if OS.is_debug_build() else Level.INFO
	var filters: Dictionary[String, Level]


	func _init(filters_str: String) -> void:
		_parse_filters(filters_str)

		var filter_strings: PackedStringArray
		for path in filters:
			filter_strings.append("%s=%s" % [path, Level.find_key(filters[path])])

		print(
			"Logging initialized with default_level=%s and filters={%s}"
			% [Level.find_key(default_level), ", ".join(filter_strings)]
		)


	func _parse_filters(filters_str: String) -> void:
		for filter in filters_str.split(",", false):
			var separator := filter.find("=")
			if separator == -1:
				var global_level: Variant = _parse_level(filter)
				if global_level != null:
					default_level = global_level
				continue

			var path := filter.left(separator)
			var level_name := filter.substr(separator + 1)
			var level: Variant = _parse_level(level_name)
			if level != null:
				filters[path] = level


	static func _parse_level(value: String) -> Variant:
		var level: Variant = Level.get(value.to_upper())
		if level == null:
			push_error("invalid logging level '%s'" % value)

		return level


	func resolve_level(source: String) -> Level:
		if not source:
			return default_level

		var resolved_level := default_level
		var best_match_length := 0

		for prefix in filters:
			if _matches(source, prefix) and prefix.length() > best_match_length:
				resolved_level = filters[prefix]
				best_match_length = prefix.length()

		return resolved_level


	static func _matches(source: String, filter: String) -> bool:
		if source == filter:
			return true

		if not source.begins_with(filter):
			return false

		# Require a path boundary so "foo" doesn't match "foobar".
		var boundary := filter.length()
		return boundary < source.length() and source[boundary] == "/"
