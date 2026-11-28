class_name AppearanceTabs
extends TabContainer

@onready var body_tabs: BodyTabs = $BodyTabs
@onready var features_tabs: LookItemsTabs = $Features
@onready var wardrobe_tabs: LookItemsTabs = $Wardrobe
@onready var thumbnail_renderer: ThumbnailRenderer = $ThumbnailRenderer


func load_state(visual: CharacterVisual) -> void:
	body_tabs.load_state(visual)
	features_tabs.load_state(visual)
	wardrobe_tabs.load_state(visual)


func deselect_item(item: LookItem) -> void:
	if item.slot.permanent:
		features_tabs.deselect_item(item)
	else:
		wardrobe_tabs.deselect_item(item)
