class_name AppearanceView
extends TabContainer

@onready var body_tab: BodyTab = $Body
@onready var features_tab: LookItemsTab = $Features


func load_state(visual: CharacterVisual) -> void:
	body_tab.load_state(visual)
	features_tab.load_state(visual)
