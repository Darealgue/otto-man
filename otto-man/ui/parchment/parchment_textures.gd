class_name ParchmentTextures
extends RefCounted
## Parşömen PNG yolları. Konum/boyut sahne node'larında kalır; sadece texture değişir.

# Büyük menüler, geniş konuşma çubuğu (tutorial), görev merkezi çerçevesi
const LARGE := "res://assets/UI/menu_ninepatchrect.png"
const LARGE_PATCH_MARGIN := 28
const LARGE_CONTENT_MARGIN := 12
# Orta paneller
const COMPACT := "res://assets/UI/menu_ninepatchrect_compact.png"
# Küçük balon, envanter (96×72)
const MINI := "res://assets/UI/menu_ninepatchrect_mini.png"
const MINI_PATCH_MARGIN := 12
const MINI_CONTENT_MARGIN := 4
const COMPACT_PATCH_MARGIN := 20
const COMPACT_CONTENT_MARGIN := 10
# İnce üst şerit (geniş, alçak; yoksa LARGE)
const HUD_BAR := "res://assets/UI/menu_ninepatchrect_hud_bar.png"


static func load_if_exists(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func resolve_mini() -> Texture2D:
	var tex := load_if_exists(MINI)
	return tex if tex else load_if_exists(COMPACT)


static func resolve_compact() -> Texture2D:
	var tex := load_if_exists(COMPACT)
	return tex if tex else load_if_exists(LARGE)


static func resolve_large() -> Texture2D:
	return load_if_exists(LARGE)


static func resolve_hud_bar() -> Texture2D:
	return load_if_exists(HUD_BAR) if load_if_exists(HUD_BAR) else load_if_exists(LARGE)


static func apply_mini(frame: ParchmentFrame, content_margin: int = MINI_CONTENT_MARGIN) -> void:
	var tex := resolve_mini()
	if tex == null or frame == null:
		return
	frame.parchment_texture = tex
	frame.patch_margin = MINI_PATCH_MARGIN
	frame.content_margin = content_margin
	frame.apply_style_now()


static func apply_compact(frame: ParchmentFrame, content_margin: int = COMPACT_CONTENT_MARGIN) -> void:
	var tex := resolve_compact()
	if tex == null or frame == null:
		return
	frame.parchment_texture = tex
	frame.patch_margin = COMPACT_PATCH_MARGIN
	frame.content_margin = content_margin
	frame.apply_style_now()


static func apply_large(frame: ParchmentFrame, content_margin: int = LARGE_CONTENT_MARGIN) -> void:
	var tex := resolve_large()
	if tex == null or frame == null:
		return
	frame.parchment_texture = tex
	frame.patch_margin = LARGE_PATCH_MARGIN
	frame.content_margin = content_margin
	frame.apply_style_now()


## PanelContainer düzenini bozmadan NinePatch (reparent yok).
static func make_ninepatch_style(
	texture: Texture2D,
	patch: int,
	content_margin: int
) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	if texture == null:
		return sb
	sb.texture = texture
	sb.texture_margin_left = patch
	sb.texture_margin_top = patch
	sb.texture_margin_right = patch
	sb.texture_margin_bottom = patch
	sb.content_margin_left = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_bottom = content_margin
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func apply_mini_panel_style(
	panel: Control,
	content_margin: int = MINI_CONTENT_MARGIN,
	patch_margin: int = -1
) -> void:
	if panel == null:
		return
	var tex := resolve_mini()
	if tex == null:
		return
	var patch := MINI_PATCH_MARGIN if patch_margin < 0 else patch_margin
	panel.add_theme_stylebox_override("panel", make_ninepatch_style(tex, patch, content_margin))


static func apply_compact_panel_style(
	panel: Control,
	content_margin: int = COMPACT_CONTENT_MARGIN,
	patch_margin: int = -1
) -> void:
	if panel == null:
		return
	var tex := resolve_compact()
	if tex == null:
		return
	var patch := COMPACT_PATCH_MARGIN if patch_margin < 0 else patch_margin
	panel.add_theme_stylebox_override("panel", make_ninepatch_style(tex, patch, content_margin))


static func apply_large_panel_style(
	panel: Control,
	content_margin: int = LARGE_CONTENT_MARGIN,
	patch_margin: int = -1
) -> void:
	if panel == null:
		return
	var tex := resolve_large()
	if tex == null:
		return
	var patch := LARGE_PATCH_MARGIN if patch_margin < 0 else patch_margin
	panel.add_theme_stylebox_override("panel", make_ninepatch_style(tex, patch, content_margin))


static func apply_parchment_styles_to_tree(root: Node) -> void:
	if root == null:
		return
	_walk_parchment_styles(root)


static func _walk_parchment_styles(node: Node) -> void:
	if node is PanelContainer or node is Panel:
		_apply_parchment_style_for(node as Control)
	for child in node.get_children():
		if child is ParchmentFrame:
			var slot := (child as ParchmentFrame).get_content_slot()
			if slot:
				_walk_parchment_styles(slot)
			continue
		_walk_parchment_styles(child)


static func _apply_parchment_style_for(panel: Control) -> void:
	if panel is PanelContainer:
		var pc := panel as PanelContainer
		if pc.get_child_count() == 0:
			return
		for c in pc.get_children():
			if c is ParchmentFrame:
				return
	var n := panel.name
	if n.ends_with("TitlePanel") or n == "HeaderPanel":
		apply_compact_panel_style(panel, 8)
	elif n.ends_with("Card") or n.ends_with("Item") or n.begins_with("ConcubineListItem"):
		apply_mini_panel_style(panel, 8)
	elif n in ["BasicInfoPanel", "SkillsPanel", "MissionHistoryPanel", "AchievementsPanel", "SelectedMissionDetailStrip"]:
		apply_compact_panel_style(panel, 10)
	elif panel is Panel:
		apply_large_panel_style(panel, 14)


static func _wrap_panel_with_texture(
	panel: PanelContainer,
	apply_tex: Callable,
	default_patch: int,
	default_content: int,
	patch_margin: int,
	content_margin: int
) -> ParchmentFrame:
	if panel == null:
		return null
	for child in panel.get_children():
		if child is ParchmentFrame:
			var pf_existing := child as ParchmentFrame
			apply_tex.call(pf_existing, content_margin if content_margin >= 0 else default_content)
			return pf_existing
	var patch := default_patch if patch_margin < 0 else patch_margin
	var cm := default_content if content_margin < 0 else content_margin
	var pf := ParchmentFrame.wrap_panel_container(panel, patch, cm)
	if pf:
		apply_tex.call(pf, cm)
	return pf


static func apply_mini_panel_backing(
	panel: PanelContainer,
	patch_margin: int = -1,
	content_margin: int = -1
) -> ParchmentFrame:
	return _wrap_panel_with_texture(
		panel,
		apply_mini,
		MINI_PATCH_MARGIN,
		MINI_CONTENT_MARGIN,
		patch_margin,
		content_margin
	)


static func apply_compact_panel_backing(
	panel: PanelContainer,
	patch_margin: int = -1,
	content_margin: int = -1
) -> ParchmentFrame:
	return _wrap_panel_with_texture(
		panel,
		apply_compact,
		COMPACT_PATCH_MARGIN,
		COMPACT_CONTENT_MARGIN,
		patch_margin,
		content_margin
	)
