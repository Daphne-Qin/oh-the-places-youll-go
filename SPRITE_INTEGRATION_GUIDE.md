# Sprite Integration Guide

## How to Add Sprite Images to Your Scenes

### Step 1: Prepare Your Sprite Images

Place your sprite images in the appropriate folders:
- **Background images**: `assets/sprites/` (or create a `backgrounds/` subfolder)
- **UI elements**: `assets/sprites/ui/` (optional)

### Step 2: Add Sprites to MainMenu.tscn

#### Option A: Using TextureRect (Recommended for Backgrounds)

1. **Open MainMenu.tscn in Godot**
2. **Select the Background node** (currently a TextureRect)
3. **In the Inspector**, click the texture field
4. **Load your Truffula forest image**:
   - Click the folder icon
   - Navigate to your sprite: `assets/sprites/backgrounds/truffula_forest.png` (or wherever you placed it)
   - Select the image

#### Option B: Using Sprite2D (For Decorative Elements)

1. **Add a new Sprite2D node** as a child of MainMenu
2. **Set the texture** to your sprite image
3. **Position it** where you want it on screen

### Step 3: Update Scene File Manually (Alternative)

If you prefer to edit the `.tscn` file directly, you can add a texture resource:

```gdscript
[ext_resource type="Texture2D" path="res://assets/sprites/backgrounds/truffula_forest.png" id="3_1"]

[node name="Background" type="TextureRect" parent="."]
texture = ExtResource("3_1")
```

### Step 4: Add Sprites to Other Scenes

The same process applies to:
- **LoraxLevel.tscn**: Add tree sprites, character sprites
- **OpeningCutscene.tscn**: Add Cat and Tree sprites
- **EndScreen.tscn**: Add decorative elements if desired

## Current Scene Structure

### MainMenu.tscn
- **Background**: TextureRect (ready for Truffula forest image)
- **Title**: "The Lorax's Quest" with Dr. Seuss-style styling
- **Buttons**: Start Demo, Quit
- **Music**: BackgroundMusic node (loads menu_theme.ogg)

### EndScreen.tscn
- **Background**: Black ColorRect
- **Title**: "DEMO COMPLETE. Thank you for playing!"
- **Stats**: "Trees Saved: 1" (placeholder)
- **Buttons**: Replay, Main Menu, Quit

## Quick Integration Steps

1. **Add your Truffula forest image**:
   ```
   assets/sprites/backgrounds/truffula_forest.png
   ```

2. **In Godot Editor**:
   - Open `scenes/MainMenu.tscn`
   - Select `Background` node
   - Drag your image to the Texture field in Inspector
   - Or click folder icon and browse to your image

3. **For Cat and Tree sprites** (OpeningCutscene):
   - Open `scenes/OpeningCutscene.tscn`
   - Select `Cat/Sprite2D` node
   - Set texture to your cat sprite
   - Select `Tree/Sprite2D` node
   - Set texture to your tree sprite

4. **For Player sprite** (LoraxLevel):
   - Open `scenes/LoraxLevel.tscn`
   - Select `Player/Sprite2D` node
   - Set texture to your player sprite

## Sprite File Formats

Godot supports:
- **PNG** (recommended for sprites with transparency)
- **JPG/JPEG** (for photos, no transparency)
- **WebP** (good compression)
- **SVG** (vector graphics)

## Sprite Organization

Recommended folder structure:
```
assets/sprites/
  ├── backgrounds/
  │   ├── truffula_forest.png
  │   └── main_menu_bg.png
  ├── player/
  │   ├── player_idle.png
  │   └── player_walk.png
  ├── cat/
  │   └── cat_sprite.png
  ├── trees/
  │   ├── tree1.png
  │   └── tree2.png
  └── ui/
      └── button_icons.png
```

## Tips

1. **Image Size**: Keep backgrounds at 1280x720 (or your game resolution) for best quality
2. **Transparency**: Use PNG for sprites that need transparent backgrounds
3. **Optimization**: Compress images before adding to reduce file size
4. **Naming**: Use descriptive names like `truffula_forest_bg.png` instead of `img1.png`

## Testing

After adding sprites:
1. Run the game (F5)
2. Check that images display correctly
3. Verify sprites scale properly on different screen sizes
4. Test that transparent areas work as expected

## Troubleshooting

**Sprite not showing?**
- Check file path is correct
- Verify image format is supported
- Check that TextureRect has `expand_mode = 1` and `stretch_mode = 6` for backgrounds

**Sprite too small/large?**
- Adjust scale in Inspector
- For backgrounds, use TextureRect with expand_mode
- For sprites, use Sprite2D and adjust scale property

**Transparency not working?**
- Ensure you're using PNG format
- Check that alpha channel is preserved in your image editor
