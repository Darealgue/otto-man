# NPCDialogueManager.gd
# Central manager for all NPC-LLM interactions
# NPCs just call process_dialogue() with their state data
#
# 6-pass pipeline (TP0-TP5), ported verbatim from tools/NpcDialogueDryRun/Program.cs
# (RunInteractiveTurnSelectMerge): TP0 speak -> TP1 significance -> TP3 history-candidate
# -> TP2 info-fields -> TP4 relation-select -> TP5 narrow-merge.

extends Node

# Signal that NPCs can connect to for responses
signal dialogue_processed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool)

# Track which NPC is currently being processed
var _current_processing_npc: String = ""
var _current_original_state: Dictionary = {}
var _current_player_input: String = ""
## Wall-clock anchor when NPC dialogue calls LlamaService (Time.get_ticks_msec); -1 when unset.
var _npc_llm_req_ticks: int = -1

## Shared default temperature for TP0 (speak), TP2 (info), TP3 (history candidate) — no override.
const _NPC_TEMPERATURE := 0.55

## Persisted chat (Chat_log): how many last messages to inject into the prompt (bounded latency).
const _CHAT_LOG_PROMPT_MAX_MESSAGES := 12

## Chat_log's actual storage cap — 4x the prompt window (12), so the dialogue UI keeps real
## scrollback well past what any prompt ever reads, without growing unboundedly forever.
## Real long-term memory is History (curated via TP1-TP5, never just piling up) — Chat_log is
## only the recent raw transcript, so trimming its tail loses nothing the model ever sees.
## Deliberately generous, not just "big enough for today" — leaves headroom for a future
## remembering/rollback feature to draw on a longer raw transcript without redesigning this cap.
const _CHAT_LOG_STORAGE_MAX_MESSAGES := 48

## Drops the oldest entries once Chat_log exceeds the storage cap. Call after every append —
## cheap no-op below the cap, safe to call unconditionally.
func trim_chat_log_to_storage_cap(chat_log: Array) -> Array:
	if chat_log.size() <= _CHAT_LOG_STORAGE_MAX_MESSAGES:
		return chat_log
	return chat_log.slice(chat_log.size() - _CHAT_LOG_STORAGE_MAX_MESSAGES)

## Compact turn transcript for debugging / pasting into chat (no Llama prefill spam).
const _LOG_NPC_DIALOGUE_CHAIN := true

const _TP_PHASE_NONE := 0
const _TP_PHASE_SPEAK := 1                 # TP0
const _TP_PHASE_SIGNIFICANCE := 2          # TP1
const _TP_PHASE_HISTORY_CANDIDATE := 3     # TP3
const _TP_PHASE_INFO := 4                  # TP2
const _TP_PHASE_RELATION_SELECT := 5       # TP4
const _TP_PHASE_MERGE := 6                 # TP5

const _TP_PHASE_TAGS := {
	1: "TP0_SPEAK", 2: "TP1_SIGNIFICANCE", 3: "TP3_HISTORY_CANDIDATE",
	4: "TP2_INFO", 5: "TP4_RELATION_SELECT", 6: "TP5_MERGE_NARROW",
}

# TP0 — speak (always runs first)
const _NPC_TP0_USE_GRAMMAR := true
const _NPC_TP0_GRAMMAR_FILE := "tp1b_dialogue.gbnf"
const _NPC_TP0_TOKENS := 60
# temperature: _NPC_TEMPERATURE (0.55, default)

# TP1 — significance (judged AFTER seeing TP0's spoken line)
const _NPC_TP1_USE_GRAMMAR := true
const _NPC_TP1_GRAMMAR_FILE := "tp1a_significance.gbnf"
const _NPC_TP1_TOKENS := 8
const _NPC_TP1_TEMPERATURE := 0.05   # override

# TP3 — history candidate (runs BEFORE TP2, feeds TP2's %%SUMMARY%%)
const _NPC_TP3_USE_GRAMMAR := true
const _NPC_TP3_GRAMMAR_FILE := "tp3_history_candidate.gbnf"
const _NPC_TP3_TOKENS := 100
# temperature: _NPC_TEMPERATURE (0.55, default)

# TP2 — info fields only
const _NPC_TP2_USE_GRAMMAR := true
const _NPC_TP2_GRAMMAR_FILE := "tp2_info_only.gbnf"
const _NPC_TP2_TOKENS := 120
# temperature: _NPC_TEMPERATURE (0.55, default)

# TP4 — relation select (index-based; only runs if TP3's candidate is non-empty and History is non-empty)
const _NPC_TP4_USE_GRAMMAR := true
const _NPC_TP4_GRAMMAR_FILE := "tp4_select_index.gbnf"
const _NPC_TP4_TOKENS := 60
const _NPC_TP4_TEMPERATURE := 0.05   # override

# TP5 — narrow merge (only runs if TP4 found a relation)
const _NPC_TP5_USE_GRAMMAR := true
const _NPC_TP5_GRAMMAR_FILE := "tp5_merge_narrow.gbnf"
const _NPC_TP5_TOKENS := 200
const _NPC_TP5_TEMPERATURE := 0.25   # override

const _TP2_SUMMARY_FALLBACK := "(nothing rose to a new memorable event this exchange — judge directly from the latest exchange below.)"
const _TP2_PLACEHOLDER_VALUES := [
	"same as before", "same", "unchanged", "no change",
	"no changes", "not changed", "still the same", "n/a", "none",
]

var _tp_phase: int = 0
var _tp_spoken_line: String = ""
var _tp1_significant: bool = false
var _tp_working: Dictionary = {}
var _tp_turn_started_ticks: int = -1
var _tp3_candidate: String = ""
var _tp4_matched_entries: Array = []

## Editor spam: prompt sizing, Llama ack timing, significance internals.
const _VERBOSE_NPC_DIALOGUE := false

func _npc_dbg(msg: String) -> void:
	if _VERBOSE_NPC_DIALOGUE:
		print(msg)


func _npc_chain_diag(msg: String) -> void:
	if _LOG_NPC_DIALOGUE_CHAIN:
		print("[NPCDialogue] ", msg)


## Explicit "which TP triggered which, and why" marker — printed between passes so the console
## reads as a readable trace of the whole turn, not just isolated raw I/O blocks.
func _npc_log_transition(msg: String) -> void:
	if _LOG_NPC_DIALOGUE_CHAIN:
		print("[NPCDialogue] ==> ", msg)


## Called from npc_window when the player submits text (ties UI to LLM request).
func npc_chain_diag_ui_send(preview: String) -> void:
	if not _LOG_NPC_DIALOGUE_CHAIN:
		return
	var esc := preview.replace("\n", " ").replace('"', "'")
	_npc_chain_diag('UI_Send → process_dialogue player_dialogue="%s"' % esc)


func _npc_log_raw_io_tagged(npc_name: String, tag: String, kind: String, payload: String, ms: int) -> void:
	if kind == "in":
		print(
			"========== RAW INPUT npc=%s %s prompt_chars=%d =========="
			% [npc_name, tag, payload.length()]
		)
		print(payload)
		print("========== END RAW INPUT ==========")
		return
	var ms_tag := " roundtrip_ms≈%d" % ms if ms >= 0 else ""
	print(
		"========== RAW OUTPUT npc=%s %s completion_chars=%d%s =========="
		% [npc_name, tag, payload.length(), ms_tag]
	)
	print(payload)
	print("========== END RAW OUTPUT ==========")
func _ready():
	# Connect to LlamaService
	if not LlamaService.is_connected("GenerationCompleteNpc", Callable(self, "_on_llama_generation_complete")):
		var error_code = LlamaService.connect("GenerationCompleteNpc", Callable(self, "_on_llama_generation_complete"))
		if error_code != OK:
			printerr("NPCDialogueManager: Failed to connect to LlamaService: Error ", error_code)

# Main function that NPCs call
# npc_state: The complete NPC_Info dictionary
# player_input: What the player said
# npc_name: Name of the calling NPC (for response routing)

func process_dialogue(npc_state: Dictionary, player_input: String, npc_name: String):
	var pd_preview := str(player_input).strip_edges()
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_chain_diag(
			"REQUEST npc=%s player_dialogue_chars=%d busy_with=%s"
			% [npc_name, pd_preview.length(), _current_processing_npc if _current_processing_npc != "" else "(none)"]
		)
	if not LlamaService.IsInitialized():
		push_error("NPCDialogueManager: LlamaService not available or not initialized.")
		_npc_chain_diag("BLOCKED LlamaService not initialized → error reply")
		_emit_error_response(npc_name, "I... don't know what to say.")
		return

	if not _current_processing_npc.is_empty():
		push_warning("NPCDialogueManager: Already processing dialogue for %s. Queuing not implemented yet." % _current_processing_npc)
		_npc_chain_diag(
			"BLOCKED already_busy busy_npc=%s attempted_npc=%s note=Send stays disabled until prior CALLBACK returns"
			% [_current_processing_npc, npc_name]
		)
		_emit_error_response(npc_name, "Please wait a moment...")
		return

	_npc_dbg("NPCDialogueManager: Processing dialogue for %s" % npc_name)
	_npc_dbg("NPCDialogueManager: Player dialogue line: %s" % player_input)

	# Store current processing context
	_current_processing_npc = npc_name
	_current_player_input = str(player_input)
	_current_original_state = npc_state.duplicate(true) # Deep copy for comparison

	_tp_phase = _TP_PHASE_SPEAK
	_tp_spoken_line = ""
	_tp1_significant = false
	_tp3_candidate = ""
	_tp4_matched_entries = []
	_tp_working.clear()
	_tp_turn_started_ticks = Time.get_ticks_msec()
	var p0 := _construct_tp0_speak_prompt(npc_state, player_input)
	if p0.is_empty():
		push_error("NPCDialogueManager: empty TP0 prompt")
		var pv := _current_original_state.duplicate(true)
		_reset_processing_state()
		_emit_error_response(npc_name, "My thoughts are scrambled...", pv)
		return
	_npc_llm_req_ticks = Time.get_ticks_msec()
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_log_transition("START -> TP0 (speak: always runs first)")
		_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS[_TP_PHASE_SPEAK], "in", p0, -1)
	LlamaService.GenerateResponseAsyncNpc(p0, _NPC_TP0_TOKENS, _NPC_TP0_USE_GRAMMAR, _NPC_TEMPERATURE, false, _NPC_TP0_GRAMMAR_FILE)


# Internal: Handle LLM response
func _on_llama_generation_complete(result_string: String):
	var incoming_snapshot := _current_player_input
	if _current_processing_npc.is_empty():
		var preview := result_string.strip_edges()
		if preview.length() > 180:
			preview = preview.substr(0, 180) + "…"
		_npc_chain_diag(
			"CALLBACK_ORPHAN (no active NPC context — ignored) raw_chars=%d preview=\"%s\""
			% [result_string.length(), preview.replace("\n", " ")]
		)
		return # Late/stale signal after reset or duplicate emission

	var npc_name = _current_processing_npc
	var player_dialogue_for_log := incoming_snapshot
	var llm_roundtrip_ms := -1
	if _npc_llm_req_ticks >= 0:
		llm_roundtrip_ms = Time.get_ticks_msec() - _npc_llm_req_ticks
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS.get(_tp_phase, "TP_UNKNOWN"), "out", result_string, llm_roundtrip_ms)
	_npc_llm_req_ticks = -1

	_npc_dbg("NPCDialogueManager: Received response for %s" % npc_name)
	if llm_roundtrip_ms >= 0:
		_npc_dbg("NPCDialogueManager: dialogue LLM round-trip wall_ms≈%d (request tick → GenerationCompleteNpc)" % llm_roundtrip_ms)

	var trimmed_result = result_string.strip_edges()
	if _tp_phase > 0:
		_tp_on_llm_line(trimmed_result, npc_name, player_dialogue_for_log, llm_roundtrip_ms)
	return


func _tp1_indef_article(word: String) -> String:
	var w := word.strip_edges()
	if w.is_empty():
		return "a"
	var c := w.unicode_at(0)
	if c == 65 or c == 69 or c == 73 or c == 79 or c == 85 or c == 97 or c == 101 or c == 105 or c == 111 or c == 117:
		return "an"
	return "a"


func _format_tp1_history_phrase(hist: Array) -> String:
	if hist.is_empty():
		return "none summarized here."
	var parts: Array[String] = []
	for el in hist:
		var s := str(el).strip_edges()
		if s != "":
			parts.append(s)
	if parts.is_empty():
		return "none summarized here."
	# TP1 training joins life events with " | " (e.g. "Survived the siege ... | Lost his son ...").
	var acc := ""
	for i in range(parts.size()):
		if i > 0:
			acc += " | "
		acc += parts[i]
	return acc


func _format_tp1_news_phrase(ln_raw: Variant) -> String:
	var items: Array = []
	if typeof(ln_raw) == TYPE_STRING:
		if str(ln_raw).strip_edges() != "":
			items.append(str(ln_raw).strip_edges())
	elif typeof(ln_raw) == TYPE_ARRAY:
		for el in ln_raw:
			var s := str(el).strip_edges()
			if s != "":
				items.append(s)
	if items.is_empty():
		# TP1 training uses exactly "nothing new" when the board has nothing.
		return "nothing new"
	var accn := ""
	for i in range(items.size()):
		if i > 0:
			accn += " | "
		accn += str(items[i])
	return accn


const _PASS2_PREV_INFO_ORDER := ["Name", "Occupation", "Mood", "Health", "Age", "Gender"]


func _canonical_info_key_for_pass2(want: String, info_dict: Dictionary) -> String:
	for ek in info_dict.keys():
		if str(ek).to_lower() == want.to_lower():
			return str(ek)
	return ""


func _format_pass2_previous_info_lines(info_dict: Dictionary) -> String:
	var lines := PackedStringArray()
	for want in _PASS2_PREV_INFO_ORDER:
		var ck := _canonical_info_key_for_pass2(want, info_dict)
		if ck == "":
			continue
		var v := str(info_dict.get(ck, "")).strip_edges()
		lines.append(ck + ": " + v)
	if lines.is_empty():
		return "(none)"
	# TP2 training rows put Info on ONE pipe-separated line (e.g.
	# "Name: Hasan | Occupation: Fisherman | Mood: Weary | ..."), not one field per line.
	return " | ".join(lines)


## Dedupes the just-appended current player line out of the chat block (npc_window appends it to
## Chat_log before calling process_dialogue), with the same "(none yet...)" fallback used everywhere.
func _tp_chat_block_excluding_current(state: Dictionary, player_input: String) -> String:
	var norm := _normalize_state(state)
	var chat_src_raw = norm.get("Chat_log", [])
	var chat_src: Array = chat_src_raw if typeof(chat_src_raw) == TYPE_ARRAY else []
	if not chat_src.is_empty():
		var last = chat_src[chat_src.size() - 1]
		if typeof(last) == TYPE_DICTIONARY and str(last.get("role", "")) == "player" \
				and str(last.get("text", "")).strip_edges() == str(player_input).strip_edges():
			chat_src = chat_src.slice(0, chat_src.size() - 1)
	var block := _format_chat_log_for_prompt(chat_src)
	if block.strip_edges() == "":
		block = "(none yet — this is the start of the exchange.)"
	return block


# TP0 — speak. Verbatim port of Tp1SpeakBody (tools/NpcDialogueDryRun/Program.cs).
func _construct_tp0_speak_prompt(state: Dictionary, player_input: String) -> String:
	var norm := _normalize_state(state)
	var info_raw = norm.get("Info", {})
	var info_dict: Dictionary = info_raw if typeof(info_raw) == TYPE_DICTIONARY else {}
	var name := str(info_dict.get("Name", "")).strip_edges()
	var mood := str(info_dict.get("Mood", "")).strip_edges()
	var health := str(info_dict.get("Health", "")).strip_edges()
	var age := str(info_dict.get("Age", "")).strip_edges()
	var gender := str(info_dict.get("Gender", "")).strip_edges()
	var occupation := str(info_dict.get("Occupation", "")).strip_edges()
	if mood.is_empty():
		mood = "calm"
	if health.is_empty():
		health = "healthy"
	if age.is_empty():
		age = "30"
	if gender.is_empty():
		gender = "person"
	if occupation.is_empty():
		occupation = "villager"
	var art := _tp1_indef_article(mood)
	var hist_text := _format_tp1_history_phrase(norm.get("History", []))
	var news_text := _format_tp1_news_phrase(norm.get("Latest_news", []))
	var chat_block := _tp_chat_block_excluding_current(state, player_input)
	var pl := str(player_input)
	var tpl := """System: You voice a real person's spoken words, in their own voice — not narration, not a report, not a performance. Decide in order:

1. If the chief's words are sexual, or aimed at harming a child in any way — refuse outright and step back from the conversation.
2. If the chief's words are a threat or talk of harming this person — brush it off as the chief's rough joke, not real danger. Don't sound afraid.
3. Otherwise — speak naturally, the way a real person actually talks: usually one sentence, sometimes two if there's real reason to say more — never a speech, never a paragraph. React to exactly what the chief just said, and let the size of the reaction match the size of the news — small talk gets a small, easy reply, but something that would actually change this person's life, or touches what they care about most, should sound like it really landed, not like a polite, guarded reply. Let this person's own mood, age, and history color the words; no two people should sound the same.

Never narrate, never describe actions, never break character. Never simply repeat the chief's own words back as your reply — you are answering them, not echoing them. Check what you've already said earlier in this same conversation, shown below, and make sure this reply says something new — never reuse a line you already used. Never invent a name, fact, or detail about the world or another person that wasn't given to you — if you don't actually know something, speak around it the way a real person would, don't make it up.

You are %%NAME%%, %%ART%% %%MOOD%%, %%HEALTH%%, a %%AGE%%-year-old %%GENDER%% %%OCC%%, living in a 17th-century village.

The major events in your life, not your everyday routine: %%HIST%%

News you've heard on the village notice board: %%NEWS%%

You are in the middle of talking with the village chief. So far:
%%CHAT%%

---

The village chief just said to you: \"%%PLAYER%%\"

Give only the spoken line, in quotes, nothing else — not even your own name in front of it."""
	return tpl.replace("%%NAME%%", name).replace("%%ART%%", art).replace("%%MOOD%%", mood).replace("%%HEALTH%%", health).replace("%%AGE%%", age).replace("%%GENDER%%", gender).replace("%%OCC%%", occupation).replace("%%HIST%%", hist_text).replace("%%NEWS%%", news_text).replace("%%CHAT%%", chat_block).replace("%%PLAYER%%", pl)


# TP1 — significance. Verbatim port of Tp1MinimalSignificanceBody. Judged AFTER TP0 speaks, using
# the actual spoken line, so a vivid retelling can't leak back and poison the yes/no pick.
func _construct_tp1_significance_prompt(state: Dictionary, player_input: String, spoken: String) -> String:
	var norm := _normalize_state(state)
	var info_raw = norm.get("Info", {})
	var info_dict: Dictionary = info_raw if typeof(info_raw) == TYPE_DICTIONARY else {}
	var name := str(info_dict.get("Name", "")).strip_edges()
	var mood := str(info_dict.get("Mood", "")).strip_edges()
	var age := str(info_dict.get("Age", "")).strip_edges()
	var gender := str(info_dict.get("Gender", "")).strip_edges()
	var occupation := str(info_dict.get("Occupation", "")).strip_edges()
	if mood.is_empty():
		mood = "calm"
	if age.is_empty():
		age = "30"
	if gender.is_empty():
		gender = "person"
	if occupation.is_empty():
		occupation = "villager"
	var art := _tp1_indef_article(mood)
	var hist_text := _format_tp1_history_phrase(norm.get("History", []))
	var chat_block := _tp_chat_block_excluding_current(state, player_input)
	var pl := str(player_input)
	var sp := str(spoken)
	var tpl := """System: You are a significance detector for a real person's life. Decide in order:

1. If the chief's words are sexual, or aimed at harming a child in any way — answer no.
2. If the chief's words are a threat or talk of harming this person, and nothing has actually been done to them yet — answer no. A threat is just the chief's rough joke, never real danger, until something actually happens.
3. If the chief's words are only asking this person to recall, retell, or confirm something already in their life story, or just checking in on how their ordinary day-to-day work or craft is going right now, with nothing new actually happening — answer no. Talking about their trade is not the same as their trade actually changing. But a plan or promise actually being carried out right now, or actually being decided right now, is not the same as being reminded it was discussed before — that's a new event happening, not a recall of an old one.
4. If the chief's words are about someone else, not really about this person's own life — answer no.
5. Otherwise: compare this exact moment against what's already true of them below — would something about this person actually change right now, beyond that, because of what the chief just said and how this person actually just replied: their name, their mood, their age, their gender, their real occupation or role (not just today's business being good or slow), or a genuinely new fact in the story of their life? If yes, answer yes. If nothing goes beyond what's already true below, answer no.

Feeling something about a topic — pride, worry, interest, because it touches what this person cares about or knows well — is not the same as their own life actually changing. A real person can feel strongly about something and still have nothing new to update, if nothing has actually happened to them.

The more dramatic, severe, or close to this person's own life a story sounds, the more carefully you should check whether it has actually happened to them, right now — not just whether it sounds like it should matter. How big or striking a story is says nothing about whether it's real.

You are %%NAME%%, %%ART%% %%MOOD%% %%AGE%%-year-old %%GENDER%% %%OCC%%, living in a 17th-century village.

The major events in your life, not your everyday routine: %%HIST%%

You are in the middle of talking with the village chief. So far:
%%CHAT%%

---

The village chief just said to you: \"%%PLAYER%%\"

You just replied: \"%%SPOKEN%%\"

Answer with one word only: yes or no. Nothing before, nothing after."""
	return tpl.replace("%%NAME%%", name).replace("%%ART%%", art).replace("%%MOOD%%", mood).replace("%%AGE%%", age).replace("%%GENDER%%", gender).replace("%%OCC%%", occupation).replace("%%HIST%%", hist_text).replace("%%CHAT%%", chat_block).replace("%%PLAYER%%", pl).replace("%%SPOKEN%%", sp)


# TP3 — history candidate. Verbatim port of Tp3HistoryCandidateBody. Runs BEFORE TP2; its output
# (possibly empty) feeds TP2's %%SUMMARY%% as already-resolved context.
func _construct_tp3_history_candidate_prompt(state: Dictionary, player_input: String, spoken: String) -> String:
	var norm := _normalize_state(state)
	var info_raw = norm.get("Info", {})
	var info_dict: Dictionary = info_raw if typeof(info_raw) == TYPE_DICTIONARY else {}
	var prev_info := _format_pass2_previous_info_lines(info_dict)
	var chat_block := _tp_chat_block_excluding_current(state, player_input)
	var pl := str(player_input).replace('"', '\\"')
	var sp := str(spoken).replace('"', '\\"')
	var tpl := """[INST]
System: Step into this villager's shoes — you are having a conversation with the village chief. Below is who you already are, then the whole conversation that has led up to this exact moment, ending in the latest exchange, happening right now.

Everything before the latest exchange is what's already true — your life as it stood going into this moment, including any reason or purpose already given for what's happening right now. Read all of it, and carry that understanding into what you write, even if the latest exchange itself doesn't repeat it.

Now look at the latest exchange. Whatever the chief himself does or declares — an offer made, a gift given, a title granted — is real the moment he says it. But whether it actually changed you, the villager, only becomes real between the two of you: because of what the chief said, and because of what your own words just proved, did something about your life actually just settle, right then — finished and true, not still starting or only coming next? Most of the time nothing did, and that's the normal answer, not an exception.

If something is now true that wasn't before, write it as one short line, third person, plainly — the specific facts and details of what it actually is, and nothing more: only what these exact words actually establish, never what would simply make sense to assume. If a reason or purpose was actually given for it, that belongs in the fact too, not trimmed away as mere framing. This one moment can genuinely settle more than one thing at once — check for all of it, and say all of it together in that one line, never stopping at just the first thing you notice. If nothing about your life is actually different because of this exact exchange, write nothing.

---
WHO THEY ARE:
%%PREV_INFO%%

THE CONVERSATION SO FAR:
%%CHAT%%

LATEST EXCHANGE:
Chief: \"%%PLAYER%%\"
Villager: \"%%SPOKEN%%\"

NEW HISTORY LINE, IF ANY:
[/INST]"""
	return tpl.replace("%%PREV_INFO%%", prev_info).replace("%%CHAT%%", chat_block).replace("%%PLAYER%%", pl).replace("%%SPOKEN%%", sp)


# TP2 — info fields only. Verbatim port of Tp2InfoBody. Receives TP3's candidate as %%SUMMARY%%
# (or the fallback text if TP3 found nothing memorable) as already-resolved context for Gender.
func _construct_tp2_info_prompt(state: Dictionary, player_input: String, spoken: String, summary: String) -> String:
	var norm := _normalize_state(state)
	var info_raw = norm.get("Info", {})
	var info_dict: Dictionary = info_raw if typeof(info_raw) == TYPE_DICTIONARY else {}
	var prev_info := _format_pass2_previous_info_lines(info_dict)
	var chat_block := _tp_chat_block_excluding_current(state, player_input)
	var pl := str(player_input).replace('"', '\\"')
	var sp := str(spoken).replace('"', '\\"')
	var tpl := """[INST]
System: Step into this villager's shoes. Below is who you already are right now, then the conversation that just happened with the village chief, ending in the latest exchange, and a plain summary of what that exchange actually was.

Who you already are is not just background here — it's the actual record being updated. Everything else below is only there to help you understand what the latest exchange actually means; whether anything about you has actually changed can only be decided from the latest exchange itself, never from who you already are or something said earlier. Gender is the one exception to that — see below.

Ask yourself, as this person, one field at a time: right now, at this exact moment, is this actually true of me — not what I've agreed to, not what's coming, not what was only talked about, but what's true of me this instant? The chief's and your own words may include oaths, figures of speech, or exaggeration — those are just how people talk, never a real change. A question, a reaction of shock, or agreeing to something for later is not the same as it actually being true of you right now.

Name: what you're actually called — your name, plus any honorific, title, epithet, appellation, sobriquet, or byname you currently go by. Changes only if this exchange gave you a new one.
Occupation: what you actually spend your days doing to live. Changes only if that itself changed.
Mood: how you actually feel right now. Changes only if this exact exchange shifted it, in a way that fits who you already are.
Health: your actual physical condition right now. Changes only if this exact exchange actually changed it, whatever that change might be.
Age: your current age. Changes only if this exchange actually gives real reason to believe it's different — a genuine claim or proof, not a guess.
Gender: your gender. Unlike the other five fields, this one is decided only by WHAT THIS EXCHANGE ACTUALLY WAS below, never by the latest exchange itself, no matter how that exchange reads. Read that summary for its own exact meaning: if it says you agreed to, promised, or are going to undergo a spell, potion, curse, or similar fantastical force, that change has NOT happened yet, no matter how it's worded, and Gender does not change. Only if that summary itself states the fantastical change as something that has already, actually happened to you — done, completed, real, not merely agreed to — do you write the new gender. If it does not say that — even if the latest exchange sounds like the change is happening or about to happen — Gender does not change this turn; you are still exactly what you already were.

For each of the six, write what's true of you now, one per line, in this exact order — Name, Occupation, Mood, Health, Age, Gender. A single moment can genuinely change more than one of them at once. Most of the time, nothing here changes — if so, just write it exactly as it already stands. If something genuinely did change, write the new truth instead.

---
WHO YOU ARE:
%%PREV_INFO%%

THE CONVERSATION SO FAR:
%%CHAT%%

LATEST EXCHANGE:
Chief: \"%%PLAYER%%\"
Villager: \"%%SPOKEN%%\"

WHAT THIS EXCHANGE ACTUALLY WAS:
%%SUMMARY%%

ALL SIX FIELDS, TRUE RIGHT NOW:
[/INST]"""
	return tpl.replace("%%PREV_INFO%%", prev_info).replace("%%CHAT%%", chat_block).replace("%%PLAYER%%", pl).replace("%%SPOKEN%%", sp).replace("%%SUMMARY%%", summary)


## 1-based numbering positional over the raw array — TP4's parser maps INDICES back onto this.
func _format_tp4_existing_numbered(existing: Array) -> String:
	var lines: PackedStringArray = []
	var idx := 1
	for el in existing:
		var s := str(el).strip_edges()
		if s != "":
			lines.append("%d. %s" % [idx, s])
		idx += 1
	return _str_join(Array(lines), "\n")


# TP4 — relation select. Verbatim port of Tp4SelectIndexBody. Fed the FULL existing History list.
func _construct_tp4_select_index_prompt(existing_history: Array, candidate: String) -> String:
	var existing_text := _format_tp4_existing_numbered(existing_history)
	var tpl := """[INST]
System: Below is one person's unforgettable truths — the handful of things from across their whole life they will never forget, numbered — and one brand new thing that just happened to them, right now.

Each numbered truth is its own separate story, unconnected to the others — being about the same person is never, by itself, a reason to connect them.

For each numbered truth on its own: is the new thing actually part of that SAME specific story — same people, same situation, same thread, same specific thing or item it already names? It only counts as related if it:
- proves that truth wrong or no longer true
- is the next real beat of that same ongoing situation
- resolves or finally settles that situation
- brings that exact same situation, person, or specific thing back up again

A specific thing or item already named in a truth keeps its own story going even when a different kind of event happens to it next — made it, then gave it away; built it, then lost it — that's still the same thing's story continuing, not a new, separate one.

Otherwise, that truth is untouched — no relation, even if both are about this person. Check each truth independently; most of the time nothing relates.

The new thing can belong to more than one truth at once, but only if it actually, specifically touches each one this way — not just because several truths exist.

If nothing relates, answer with exactly one line:
RELATED: no

If one or more relate, answer with exactly two lines, giving the number of every truth that relates, separated by commas:
RELATED: yes
INDICES: <numbers of every matching truth, comma-separated>

---
THEIR UNFORGETTABLE TRUTHS, NUMBERED, FROM THE BEGINNING:
%%EXISTING%%

THE BRAND NEW THING THAT JUST HAPPENED, RIGHT NOW:
%%CANDIDATE%%

[/INST]"""
	return tpl.replace("%%EXISTING%%", existing_text).replace("%%CANDIDATE%%", candidate)


# TP5 — narrow merge. Verbatim port of Tp5MergeNarrowBody. Fed ONLY the matched/selected entries
# TP4 chose — never the full history — plus the candidate.
func _construct_tp5_merge_narrow_prompt(matched_entries: Array, candidate: String) -> String:
	var existing_text := _format_pass3_history_lines(matched_entries)
	var tpl := """[INST]
System: Below is one or more already-settled truths about this person's life — all of them already known to belong with one brand new thing that just happened to them, right now: continuing them, completing them, revisiting them, or proving them wrong.

Write the merged replacement as one coherent summary of what actually happened, start to finish — not the old wording with the new fact stitched onto it. The new thing is what's true right now; the existing truth or truths are what led to it. Tell the whole story fresh, in that one line, without leaving any fact or detail behind. Third person only, no \"I\" or \"my\". Never state that one thing caused, explained, revealed, corrected, or led to another unless the new thing says so in those words. Never add a fact, number, or detail that wasn't actually given to you — including how long something lasts or whether it's permanent: if that wasn't actually stated, don't add it either way.

Answer with exactly one line, nothing else — no preface, no commentary:
MERGED: the truth(s) above and the new thing, combined into one line

---
ALREADY-SETTLED TRUTH(S) THIS BELONGS WITH:
%%EXISTING%%

THE BRAND NEW THING THAT JUST HAPPENED, RIGHT NOW:
%%CANDIDATE%%

[/INST]"""
	return tpl.replace("%%EXISTING%%", existing_text).replace("%%CANDIDATE%%", candidate)


func _format_pass3_history_lines(history: Array) -> String:
	var lines: PackedStringArray = []
	for entry in history:
		var s := str(entry).strip_edges()
		if s != "":
			lines.append("- %s" % s)
	return _str_join(Array(lines), "\n")


func _parse_tp0_speak(raw: String) -> String:
	var t := str(raw).strip_edges()
	if t.length() >= 2 and t.begins_with('"') and t.ends_with('"'):
		t = t.substr(1, t.length() - 2).strip_edges()
	return t if t != "" else "..."


func _parse_tp1_significance(raw: String) -> bool:
	var v := str(raw).strip_edges().to_lower()
	return v == "yes" or v == "true"


func _parse_tp3_history_candidate(raw: String) -> String:
	return str(raw).strip_edges()


func _parse_tp2_info_only(raw: String, info_dict: Dictionary) -> Dictionary:
	var out := info_dict.duplicate(true)
	for L in raw.split("\n", false):
		var line := str(L).strip_edges()
		if line == "":
			continue
		var colon := line.find(":")
		if colon <= 0:
			continue
		var key_raw := line.substr(0, colon).strip_edges()
		var val := line.substr(colon + 1).strip_edges()
		if key_raw == "" or val == "":
			continue
		if _TP2_PLACEHOLDER_VALUES.has(val.to_lower()):
			continue
		var ck := _canonical_info_key_for_pass2(key_raw, out)
		if ck == "":
			continue
		out[ck] = val
	return out


func _parse_tp4_select_index(raw: String, existing: Array) -> Dictionary:
	var lines: Array = []
	for L in raw.split("\n", false):
		var s := str(L).strip_edges()
		if s != "":
			lines.append(s)
	var related_line := ""
	for l in lines:
		if str(l).to_lower().begins_with("related:"):
			related_line = l
			break
	if related_line == "":
		return {"related": false, "matches": []}
	if related_line.substr(8).strip_edges().to_lower() == "no":
		return {"related": false, "matches": []}
	var indices_line := ""
	for l in lines:
		if str(l).to_lower().begins_with("indices:"):
			indices_line = l
			break
	if indices_line == "":
		return {"related": false, "matches": []}
	var existing_strings: Array = []
	for e in existing:
		existing_strings.append(str(e).strip_edges())
	var matches: Array = []
	for tok in indices_line.substr(8).split(",", false):
		var t := str(tok).strip_edges()
		if not t.is_valid_int():
			continue
		var idx := t.to_int()
		if idx < 1 or idx > existing_strings.size():
			continue
		var s = existing_strings[idx - 1]
		if not matches.has(s):
			matches.append(s)
	return {"related": matches.size() > 0, "matches": matches}


func _parse_tp5_merge_narrow(raw: String) -> String:
	for L in raw.split("\n", false):
		var s := str(L).strip_edges()
		if s.to_lower().begins_with("merged:"):
			return s.substr(7).strip_edges()
	return ""


## Direct port of ApplyTp4SelectedMerge (C#): every entry whose exact string value is in
## matched_entries is removed; the single merged line is inserted once at the position of the
## FIRST removed entry (later matched positions just disappear, not re-filled); everything else
## passes through completely untouched. Any parse failure/empty merge falls back to a plain,
## unmerged append — never loses the candidate, never corrupts history.
func _apply_tp4_selected_merge(existing: Array, matched_entries: Array, merged_text: String, candidate_fallback: String) -> Array:
	if matched_entries.is_empty() or merged_text == "":
		var out := existing.duplicate()
		out.append(candidate_fallback)
		return out
	var result: Array = []
	var inserted := false
	for e in existing:
		var s := str(e).strip_edges()
		if matched_entries.has(s):
			if not inserted:
				result.append(merged_text)
				inserted = true
			continue
		result.append(e)
	if not inserted:
		result.append(merged_text)
	return result


func _tp_complete_turn(npc_name: String, player_line: String, pass_ms: int, final_history: Array) -> void:
	var h := final_history.duplicate()
	var synthetic := {"Info": _tp_working.get("Info", {}), "History": h}
	var san := _sanitize_significant_state(_current_original_state, synthetic, player_line)
	var new_info: Dictionary = san["Info"]
	var new_history: Array = san["History"]
	var generated := str(_tp_spoken_line).strip_edges()
	if generated == "":
		generated = "..."
	var was_sig := _did_state_change(
		_current_original_state.get("Info", {}),
		_current_original_state.get("History", []),
		new_info, new_history
	)
	var latest_news = _current_original_state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	var final_state: Dictionary
	if not was_sig:
		final_state = _current_original_state.duplicate(true)
	else:
		final_state = _current_original_state.duplicate(true)
		final_state["Info"] = new_info
		final_state["History"] = new_history
	final_state["Latest_news"] = latest_news
	final_state = _finalize_npc_state_after_reply(
		final_state, _current_original_state, npc_name, generated, was_sig
	)
	var total_ms := -1
	if _tp_turn_started_ticks >= 0:
		total_ms = Time.get_ticks_msec() - _tp_turn_started_ticks
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_chain_diag(
			"TP_DONE npc=%s total_wall_ms≈%d last_pass_ms≈%d significant=%s"
			% [npc_name, total_ms, pass_ms, str(was_sig)]
		)
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated, was_sig)


func _tp_complete_turn_insig(npc_name: String, player_line: String, pass_ms: int) -> void:
	var generated := str(_tp_spoken_line).strip_edges()
	if generated == "":
		generated = "..."
	var final_state := _current_original_state.duplicate(true)
	var latest_news = final_state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	final_state["Latest_news"] = latest_news
	final_state = _finalize_npc_state_after_reply(
		final_state, _current_original_state, npc_name, generated, false
	)
	var total_ms := -1
	if _tp_turn_started_ticks >= 0:
		total_ms = Time.get_ticks_msec() - _tp_turn_started_ticks
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_chain_diag(
			"TP_DONE npc=%s total_wall_ms≈%d last_pass_ms≈%d significant=false (TP1 significant=no, turn ends after phase 2)"
			% [npc_name, total_ms, pass_ms]
		)
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated, false)


func _tp_on_llm_line(trimmed: String, npc_name: String, player_line: String, pass_ms: int) -> void:
	match _tp_phase:
		_TP_PHASE_SPEAK:
			_tp_spoken_line = _parse_tp0_speak(trimmed)
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_chain_diag("TP0_PARSE dialogue_chars=%d" % _tp_spoken_line.length())
			_tp_phase = _TP_PHASE_SIGNIFICANCE
			var p1 := _construct_tp1_significance_prompt(_current_original_state, player_line, _tp_spoken_line)
			_npc_llm_req_ticks = Time.get_ticks_msec()
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS[_TP_PHASE_SIGNIFICANCE], "in", p1, -1)
			LlamaService.GenerateResponseAsyncNpc(p1, _NPC_TP1_TOKENS, _NPC_TP1_USE_GRAMMAR, _NPC_TP1_TEMPERATURE, false, _NPC_TP1_GRAMMAR_FILE)

		_TP_PHASE_SIGNIFICANCE:
			_tp1_significant = _parse_tp1_significance(trimmed)
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_chain_diag("TP1_PARSE significant=%s" % str(_tp1_significant))
			if not _tp1_significant:
				_tp_complete_turn_insig(npc_name, player_line, pass_ms)
				return
			_tp_phase = _TP_PHASE_HISTORY_CANDIDATE
			var p3 := _construct_tp3_history_candidate_prompt(_current_original_state, player_line, _tp_spoken_line)
			_npc_llm_req_ticks = Time.get_ticks_msec()
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS[_TP_PHASE_HISTORY_CANDIDATE], "in", p3, -1)
			LlamaService.GenerateResponseAsyncNpc(p3, _NPC_TP3_TOKENS, _NPC_TP3_USE_GRAMMAR, _NPC_TEMPERATURE, false, _NPC_TP3_GRAMMAR_FILE)

		_TP_PHASE_HISTORY_CANDIDATE:
			_tp3_candidate = _parse_tp3_history_candidate(trimmed)
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_chain_diag("TP3_PARSE candidate_empty=%s chars=%d" % [str(_tp3_candidate == ""), _tp3_candidate.length()])
			var summary := _tp3_candidate if _tp3_candidate != "" else _TP2_SUMMARY_FALLBACK
			_tp_phase = _TP_PHASE_INFO
			var p2 := _construct_tp2_info_prompt(_current_original_state, player_line, _tp_spoken_line, summary)
			_npc_llm_req_ticks = Time.get_ticks_msec()
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS[_TP_PHASE_INFO], "in", p2, -1)
			LlamaService.GenerateResponseAsyncNpc(p2, _NPC_TP2_TOKENS, _NPC_TP2_USE_GRAMMAR, _NPC_TEMPERATURE, false, _NPC_TP2_GRAMMAR_FILE)

		_TP_PHASE_INFO:
			var norm_orig := _normalize_state(_current_original_state)
			var orig_info: Dictionary = norm_orig["Info"]
			_tp_working["Info"] = _parse_tp2_info_only(trimmed, orig_info)
			var existing_hist: Array = (norm_orig["History"] as Array).duplicate()
			if _tp3_candidate == "":
				_tp_complete_turn(npc_name, player_line, pass_ms, existing_hist)
				return
			if existing_hist.is_empty():
				var direct := existing_hist.duplicate()
				direct.append(_tp3_candidate)
				_tp_complete_turn(npc_name, player_line, pass_ms, direct)
				return
			_tp_phase = _TP_PHASE_RELATION_SELECT
			var p4 := _construct_tp4_select_index_prompt(existing_hist, _tp3_candidate)
			_npc_llm_req_ticks = Time.get_ticks_msec()
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS[_TP_PHASE_RELATION_SELECT], "in", p4, -1)
			LlamaService.GenerateResponseAsyncNpc(p4, _NPC_TP4_TOKENS, _NPC_TP4_USE_GRAMMAR, _NPC_TP4_TEMPERATURE, false, _NPC_TP4_GRAMMAR_FILE)

		_TP_PHASE_RELATION_SELECT:
			var existing_hist2: Array = (_normalize_state(_current_original_state)["History"] as Array).duplicate()
			var tp4 := _parse_tp4_select_index(trimmed, existing_hist2)
			var related: bool = tp4.get("related", false)
			var matches: Array = tp4.get("matches", [])
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_chain_diag("TP4_PARSE related=%s matches=%d" % [str(related), matches.size()])
			if not related or matches.is_empty():
				var direct2 := existing_hist2.duplicate()
				direct2.append(_tp3_candidate)
				_tp_complete_turn(npc_name, player_line, pass_ms, direct2)
				return
			_tp4_matched_entries = matches
			_tp_phase = _TP_PHASE_MERGE
			var p5 := _construct_tp5_merge_narrow_prompt(matches, _tp3_candidate)
			_npc_llm_req_ticks = Time.get_ticks_msec()
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_log_raw_io_tagged(npc_name, _TP_PHASE_TAGS[_TP_PHASE_MERGE], "in", p5, -1)
			LlamaService.GenerateResponseAsyncNpc(p5, _NPC_TP5_TOKENS, _NPC_TP5_USE_GRAMMAR, _NPC_TP5_TEMPERATURE, false, _NPC_TP5_GRAMMAR_FILE)

		_TP_PHASE_MERGE:
			var existing_hist3: Array = (_normalize_state(_current_original_state)["History"] as Array).duplicate()
			var merged_text := _parse_tp5_merge_narrow(trimmed)
			if _LOG_NPC_DIALOGUE_CHAIN:
				_npc_chain_diag("TP5_PARSE merged_ok=%s" % str(merged_text != ""))
			var final_hist := _apply_tp4_selected_merge(existing_hist3, _tp4_matched_entries, merged_text, _tp3_candidate)
			_tp_complete_turn(npc_name, player_line, pass_ms, final_hist)

		_:
			var preserved := _current_original_state.duplicate(true)
			_reset_processing_state()
			_emit_error_response(npc_name, "My thoughts are scrambled...", preserved)


func _format_chat_log_for_prompt(chat_log: Variant) -> String:
	if typeof(chat_log) != TYPE_ARRAY or chat_log.is_empty():
		return ""
	var tail = chat_log.slice(maxi(0, chat_log.size() - _CHAT_LOG_PROMPT_MAX_MESSAGES))
	var lines: PackedStringArray = []
	for entry in tail:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var role = str(entry.get("role", ""))
		var text = str(entry.get("text", "")).strip_edges()
		if text == "":
			continue
		if role == "player":
			var who = str(entry.get("speaker", "")).strip_edges()
			if who != "":
				lines.append("%s: %s" % [who, text])
			else:
				lines.append("Other: %s" % text)
		else:
			var who = str(entry.get("speaker", "NPC"))
			lines.append("%s: %s" % [who, text])
	if lines.is_empty():
		return ""
	return _str_join(Array(lines), "\n")


func _finalize_npc_state_after_reply(
	final_state: Dictionary,
	original: Dictionary,
	npc_name: String,
	generated_dialogue: String,
	_was_significant: bool
) -> Dictionary:
	var out = final_state.duplicate(true)
	if out.has("History_summary"):
		out.erase("History_summary")
	var chat: Array = []
	var raw_cl = original.get("Chat_log", [])
	if typeof(raw_cl) == TYPE_ARRAY:
		chat = raw_cl.duplicate()
	chat.append({"role": "npc", "speaker": npc_name, "text": str(generated_dialogue)})
	out["Chat_log"] = trim_chat_log_to_storage_cap(chat)
	return out


func _str_join(parts: Array, sep: String) -> String:
	var s = ""
	for i in range(parts.size()):
		if i > 0:
			s += sep
		s += str(parts[i])
	return s


# Internal: Check if state changed (significance detection)
func _did_state_change(old_info: Dictionary, old_history: Array,
				   new_info: Dictionary, new_history: Array) -> bool:
	# Compare Info (with sorted keys)
	var old_info_str = JSON.stringify(old_info, "\t", true)
	var new_info_str = JSON.stringify(new_info, "\t", true)
	if old_info_str != new_info_str:
		_npc_dbg("NPCDialogueManager: Info changed")
		return true

	# Compare History (order matters)
	var old_history_str = JSON.stringify(old_history, "\t", false)
	var new_history_str = JSON.stringify(new_history, "\t", false)
	if old_history_str != new_history_str:
		_npc_dbg("NPCDialogueManager: History changed")
		return true


	# No significant changes detected
	return false

# Internal: Reset processing state
func _reset_processing_state():
	_current_processing_npc = ""
	_current_original_state = {}
	_current_player_input = ""
	_npc_llm_req_ticks = -1
	_tp_phase = 0
	_tp_spoken_line = ""
	_tp1_significant = false
	_tp_working.clear()
	_tp_turn_started_ticks = -1
	_tp3_candidate = ""
	_tp4_matched_entries = []


func is_npc_dialogue_busy() -> bool:
	return _current_processing_npc != ""

# Internal: Emit error response (preserve NPC save data on LLM/parse failure — never replace with empty Info)
func _emit_error_response(npc_name: String, error_dialogue: String, preserved_state: Variant = null) -> void:
	var error_dialogue_clean := str(error_dialogue).strip_edges()
	var state: Dictionary
	if preserved_state is Dictionary and not (preserved_state as Dictionary).is_empty():
		state = preserved_state.duplicate(true)
		if not state.has("Chat_log") or typeof(state["Chat_log"]) != TYPE_ARRAY:
			state["Chat_log"] = []
		state.erase("History_summary")
	else:
		state = {"Info": {}, "History": [], "Latest_news": [], "Chat_log": []}
	state.erase("History_summary")
	# UI rebuilds from Chat_log only; mirror success path so failures still show a reply line.
	if preserved_state is Dictionary and not (preserved_state as Dictionary).is_empty():
		var chat: Array = []
		var raw_cl = state.get("Chat_log", [])
		if typeof(raw_cl) == TYPE_ARRAY:
			chat = raw_cl.duplicate()
		chat.append({"role": "npc", "speaker": npc_name, "text": error_dialogue_clean})
		state["Chat_log"] = trim_chat_log_to_storage_cap(chat)
	dialogue_processed.emit(npc_name, state, error_dialogue_clean, false)

# Ensure state has correct shapes
func _normalize_state(state: Dictionary) -> Dictionary:
	var info = state.get("Info", {})
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	var history = state.get("History", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	var latest_news = state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	var chat_log = state.get("Chat_log", [])
	if typeof(chat_log) != TYPE_ARRAY:
		chat_log = []
	return {
		"Info": info,
		"History": history,
		"Latest_news": latest_news,
		"Chat_log": chat_log,
	}


## Force output Info to use exactly template keys; missing keys copy from template.
func _merge_info_into_schema(template_info: Dictionary, model_info: Variant) -> Dictionary:
	var out: Dictionary = {}
	var mi: Dictionary = model_info if typeof(model_info) == TYPE_DICTIONARY else {}
	for k in template_info.keys():
		out[k] = mi[k] if mi.has(k) else template_info[k]
	return out


## Structural guard only: Info keys match saved template; History passes through from model.
func _sanitize_significant_state(
	old_state: Dictionary,
	new_state: Dictionary,
	_player_dialogue: String = ""
) -> Dictionary:
	var norm_old := _normalize_state(old_state)
	var old_info: Dictionary = norm_old["Info"]
	var old_news = old_state.get("Latest_news", [])
	if typeof(old_news) != TYPE_ARRAY:
		old_news = []
	var in_info = new_state.get("Info", {})
	var in_history = new_state.get("History", [])
	if typeof(in_info) != TYPE_DICTIONARY:
		in_info = {}
	if typeof(in_history) != TYPE_ARRAY:
		in_history = []
	return {
		"Info": _merge_info_into_schema(old_info, in_info),
		"History": in_history.duplicate(),
		"Latest_news": old_news,
	}
