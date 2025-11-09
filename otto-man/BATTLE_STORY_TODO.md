# Battle Story System - TODO for Next Session

## ✅ Completed Today
- Added optional `useGrammar` parameter to `LlamaService.GenerateResponseAsync()` for grammar-free generation
- Created battle story generation system in `WorldManager.gd`
- Integrated battle stories into news system (posted to World News)
- Enhanced news detail view for longer battle stories (scrollable, larger panel)
- Added `test_battle` dev console command for testing
- Fixed autoload singleton access in dev console (using direct names instead of get_node)

## 📝 TODO for Tomorrow

### 1. Village News Board - NPC Reading System
- Find the village news board location/UI
- Implement NPCs reading news from the board
- Make NPCs aware of recent news/battle stories

### 2. Battle Story Improvements
- Tweak battle story prompts to generate shorter stories
- Make stories more contextually appropriate
- Adjust prompt parameters (max tokens, temperature, etc.)

### 3. NPC-to-NPC Dialogue System
- Implement NPCs talking to each other
- Create conversation triggers between NPCs
- Integrate with existing dialogue system

### 4. Multi-Language Support (Turkish/English)
- Add language settings system (interchangeable)
- Create Turkish versions of all dialogues
- Create Turkish versions of battle stories
- Update LLM prompts to generate in selected language
- Integrate language selection with existing settings/UI

## Notes
- User manually fixed the `useGrammar` parameter in dialogue calls (should verify all dialogue calls have it)
- Battle stories are currently generated with 500 tokens - may need to reduce for shorter stories
- News system is working and stories appear in World News panel with detail view on click

