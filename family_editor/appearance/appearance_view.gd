class_name AppearanceView
extends TabContainer

@onready var body_tab: BodyTab = $Body
@onready var features_tab: LookItemsTab = $Features
@onready var wardrobe_tab: LookItemsTab = $Wardrobe


func load_state(visual: CharacterVisual) -> void:
	body_tab.load_state(visual)
	load_look_state(visual)


func load_look_state(visual: CharacterVisual) -> void:
	features_tab.load_state(visual)
	wardrobe_tab.load_state(visual)
