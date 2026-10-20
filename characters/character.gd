class_name Character
extends Node3D

enum AnimationStyle {
	FEMININE,
	MASCULINE,
}

@export var visual: CharacterVisual

var first_name: String
var last_name: String
var animation_style: AnimationStyle
