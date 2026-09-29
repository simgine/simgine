class_name UpMenuButton
extends MenuButton
## Like [MenuButton], but shows its popup up above.


func _ready() -> void:
	get_popup().about_to_popup.connect(_position_popup)


func _position_popup() -> void:
	var popup := get_popup()
	popup.position.y -= popup.size.y + size.y as int
