# Chat Interface Integration Guide

## ✅ What's Been Integrated

The Lorax chat interface is now **fully integrated** into the LoraxLevel scene!

## 🎮 How It Works

### 1. **Interaction System**
- When the player walks near the Lorax, an interaction prompt appears
- Prompt says: "Press [E] to talk with the Lorax"
- Prompt fades in/out smoothly

### 2. **Opening the Chat**
- Press **E** (or **Enter/Space**) when near the Lorax
- Chat interface opens with smooth animation
- Player movement is automatically disabled during chat

### 3. **Chatting with the Lorax**
- Type your message in the input field
- Press **Enter** or click **Send** to send
- Lorax responds in character (short, wise, poetic messages)
- Conversation history is maintained (last 10 messages)

### 4. **Closing the Chat**
- Press **Escape** or click the **✕** button
- Chat closes with smooth animation
- Player movement is re-enabled

## 🎨 Visual Features

- **Interaction Prompt**: Yellow text with green outline (Seussian style)
- **Chat Interface**: Orange/green themed panel with rounded corners
- **Message Bubbles**: 
  - Orange for Lorax (left-aligned)
  - Blue for user (right-aligned)
- **Smooth Animations**: All UI elements fade and scale smoothly

## 🔧 Technical Details

### Scene Structure
```
LoraxLevel
├── Player (CharacterBody2D)
├── Interactables
│   └── LoraxArea (Area2D) - Detects when player is near
└── UILayer (CanvasLayer) - Created dynamically
    ├── Interaction Prompt (Label)
    └── ChatInterface (Control)
```

### Scripts
- **`lorax_level.gd`**: Manages level, interactions, and chat loading
- **`lorax_chat.gd`**: Handles chat UI and message display
- **`api_manager.gd`**: Handles API calls and Lorax responses

### Signals & Events
- `body_entered` / `body_exited`: Detects player proximity
- `lorax_message_received`: When Lorax responds
- `lorax_message_failed`: If API call fails

## 🎯 Usage Flow

1. **Player walks to Lorax** → Prompt appears
2. **Player presses E** → Chat opens
3. **Player types message** → Sends to API
4. **Lorax responds** → Message appears in chat
5. **Continue conversation** → Back and forth dialogue
6. **Press Escape** → Chat closes, player can move again

## 🐛 Troubleshooting

### Prompt doesn't appear
- Check that `LoraxArea` has a `CollisionShape2D` child
- Verify the collision shape size covers the interaction area
- Make sure `monitorable = false` is set (so other areas don't detect it)

### Chat doesn't open
- Check that E key is working (or try Enter/Space)
- Verify `is_near_lorax` is true (check console)
- Make sure chat instance loaded successfully

### Lorax doesn't respond
- Check API key is configured in `project.godot`
- Look at Output panel for API errors
- Verify internet connection

### Messages not appearing
- Check that signals are connected in `lorax_chat.gd`
- Verify API manager is initialized (autoload)
- Look for errors in Output panel

## 🎨 Customization

### Change Interaction Key
In `lorax_level.gd`, modify `_input()`:
```gdscript
if event.is_action_pressed("ui_select") or (event is InputEventKey and event.keycode == KEY_F and event.pressed):
    # Change KEY_E to KEY_F or any other key
```

### Change Prompt Text
In `lorax_level.gd`, modify `_create_interaction_prompt()`:
```gdscript
interaction_prompt.text = "Press [F] to chat with the Lorax"
```

### Adjust Interaction Area
In the scene, select `LoraxArea` → `CollisionShape2D` → Adjust the shape size

### Change Chat Position
The chat is centered by default. To change position, modify `LoraxChat.tscn

## ✅ Everything is Ready!

The chat interface is fully integrated and ready to use. Just:
1. Run the game (F5)
2. Walk to the Lorax
3. Press E when the prompt appears
4. Start chatting!

The Lorax will respond in character with short, wise messages about the environment. 🎉
