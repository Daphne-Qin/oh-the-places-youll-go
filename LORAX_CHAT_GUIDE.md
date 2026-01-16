# Lorax Chat Interface Guide

## 🎨 Overview

A beautiful, Seussian-styled chat interface that lets players have conversations with the Lorax using the Gemini API. The Lorax responds in character with short, wise messages about the environment.

## ✨ Features

- **Conversational AI**: Back-and-forth dialogue with the Lorax
- **Lorax Personality**: Responses in the voice of the Lorax (short, wise, poetic)
- **Visual Design**: Seussian colors (orange, green, yellow) with rounded bubbles
- **Smooth Animations**: Message bubbles fade in with scale animations
- **Typing Indicator**: Shows when the Lorax is thinking
- **Conversation History**: Maintains context across messages (last 10 messages)

## 🎮 How to Use

### Opening the Chat

Add this to any script where you want to open the chat:

```gdscript
# Get the chat scene
var chat_scene = preload("res://scenes/LoraxChat.tscn")
var chat_instance = chat_scene.instantiate()
get_tree().current_scene.add_child(chat_instance)
chat_instance.open_chat()
```

### Example: Add to Lorax Level

In `LoraxLevel.tscn` or your level script:

```gdscript
func _ready() -> void:
	# Add chat interface
	var chat_scene = preload("res://scenes/LoraxChat.tscn")
	var chat_instance = chat_scene.instantiate()
	add_child(chat_instance)
	
	# Open chat when player interacts with Lorax
	# (You can trigger this from a button, collision, etc.)
```

### Keyboard Shortcuts

- **Enter**: Send message
- **Escape**: Close chat

## 🎨 Visual Design

### Colors
- **Lorax Messages**: Orange (`Color(0.9, 0.6, 0.2)`) - Warm, friendly
- **User Messages**: Blue (`Color(0.2, 0.6, 0.9)`) - Cool, distinct
- **Background**: Dark green with orange border - Seussian theme
- **Text**: White for readability

### Animations
- **Open/Close**: Fade and scale animations
- **Message Bubbles**: Fade in with scale effect
- **Typing Indicator**: Pulsing opacity

## 🔧 API Integration

The chat uses `APIManager.send_message_to_lorax()` which:

1. **Maintains Conversation History**: Remembers last 10 messages
2. **Lorax Personality Prompt**: 
   - "You are the Lorax from Dr. Seuss's 'The Lorax'"
   - "Keep responses SHORT (1-2 sentences max)"
   - "Be wise, caring, and use simple, poetic language"
3. **Short Responses**: Enforced in the prompt to keep replies concise

## 📝 Message Flow

1. User types message → Presses Enter or Send
2. Message appears in chat (blue bubble, right-aligned)
3. Typing indicator shows "The Lorax is thinking..."
4. API call made with conversation history
5. Lorax response appears (orange bubble, left-aligned)
6. Conversation continues...

## 🎯 Customization

### Change Colors

In `lorax_chat.gd`, modify `_create_message_bubble()`:

```gdscript
if is_user:
	style.bg_color = Color(0.2, 0.6, 0.9, 1)  # User color
else:
	style.bg_color = Color(0.9, 0.6, 0.2, 1)  # Lorax color
```

### Change Welcome Message

In `lorax_chat.gd`, modify `_add_welcome_message()`:

```gdscript
var welcome_text = "Your custom welcome message here!"
```

### Adjust Conversation History

In `api_manager.gd`, modify `send_message_to_lorax()`:

```gdscript
# Limit conversation history to last 10 messages
if conversation_history.size() > 10:  # Change 10 to desired limit
	conversation_history = conversation_history.slice(-10)
```

## 🐛 Troubleshooting

### Chat doesn't open
- Check that the scene path is correct: `res://scenes/LoraxChat.tscn`
- Verify the chat instance is added to the scene tree

### Messages not appearing
- Check API key is configured
- Look at Output panel for API errors
- Verify signals are connected in `_ready()`

### Lorax responses too long
- The prompt enforces short responses, but you can strengthen it:
  - In `api_manager.gd`, modify the system prompt to emphasize brevity

### Conversation loses context
- History is limited to 10 messages to avoid token limits
- Increase limit if needed (but watch API costs)

## 🚀 Next Steps

1. **Add to Game**: Integrate chat into your level scenes
2. **Add Trigger**: Create a button or interaction to open chat
3. **Add Avatar**: Replace placeholder with Lorax sprite
4. **Add Sounds**: Play sounds when messages arrive
5. **Add Animations**: Animate Lorax avatar when speaking

## 💡 Tips

- **Keep it Short**: The Lorax prompt enforces 1-2 sentence responses
- **Test API**: Make sure API key works before testing chat
- **Monitor Costs**: Each message uses API tokens (conversation history increases cost)
- **Fallback**: If API fails, shows friendly error message

The chat interface is ready to use! Just add it to your scene and call `open_chat()`.
