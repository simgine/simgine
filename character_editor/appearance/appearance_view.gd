class_name AppearanceView
extends TabContainer

@onready var body_tab: BodyTab = $Body
@onready var features_tab: LookItemsTab = $Features
@onready var wardrobe_tab: LookItemsTab = $Wardrobe


func load_state(visual: CharacterVisual) -> void:
	body_tab.load_state(visual)
	features_tab.load_state(visual)
	wardrobe_tab.load_state(visual)


func select_item(item: LookItem) -> void:
	features_tab.select_item(item)
	wardrobe_tab.select_item(item)


func deselect_item(item: LookItem) -> void:
	features_tab.deselect_item(item)
	wardrobe_tab.deselect_item(item)
