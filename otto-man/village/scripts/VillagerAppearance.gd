# VillagerAppearance.gd
extends Resource
class_name VillagerAppearance

# --- Body ---
@export var body_texture: CanvasTexture = null
@export var body_tint: Color = Color.WHITE # Default White = no tinting

# --- Pants ---
@export var pants_texture: CanvasTexture = null
@export var pants_tint: Color = Color.WHITE # Pantolon rengi

# --- Clothes ---
@export var clothing_texture: CanvasTexture = null
@export var clothing_tint: Color = Color.WHITE

# --- Mouth ---
@export var mouth_texture: CanvasTexture = null

# --- Eyes ---
@export var eyes_texture: CanvasTexture = null

# --- Beard (Optional) ---
@export var beard_texture: CanvasTexture = null
# Sakal rengi için saç rengini kullanabiliriz veya ayrı bir tint ekleyebiliriz:
# @export var beard_tint: Color = Color.WHITE

# --- Hair ---
@export var hair_texture: CanvasTexture = null
@export var hair_tint: Color = Color.WHITE # Default White = no tinting

# Add more parts as needed (e.g., nose, mouth, accessories) 
