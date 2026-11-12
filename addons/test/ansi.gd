class_name Ansi

const RED := "\u001b[0;31m"
const GREEN := "\u001b[0;32m"
const BOLD_BRIGHT_GREEN := "\u001b[0;1;92m"


static func paint(text: String, style: String) -> String:
	const RESET := "\u001b[0m"
	if OS.get_stdout_type() != OS.STD_HANDLE_CONSOLE:
		return text
	return style + text + RESET
