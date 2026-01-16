# Placeholder Menu System Guide

## 🎯 Overview

This is a placeholder-based main menu system with **wobble physics**, **parallax scrolling**, and **smooth transitions**. All visual elements use simple colored shapes that can easily be replaced with real art later.

## ✨ Key Features

### 1. **Wobble Physics System**
- Automatically finds all nodes with "Wobble" in their name
- Spring-based physics with damping for natural teetering motion
- Continuous gentle motion using sine/cosine waves
- Rotation based on velocity for realistic teetering effect

**How it works:**
- Each wobble element has a base position
- Spring force pulls it back to base position
- Random forces add continuous gentle motion
- Velocity is damped for smooth, natural movement

### 2. **Parallax Scrolling**
- 4 layers with different scroll speeds:
  - **Sky Layer** (0.1x) - Background gradient
  - **Cloud Layer** (0.3x) - Floating clouds
  - **Tree Layer** (0.6x) - Truffula trees
  - **Foreground Layer** (1.0x) - Wobble stacks
- Continuous horizontal scrolling
- Automatic looping when reaching edge

### 3. **Smooth Transitions**
- Button hover effects with scale and color modulation
- Smooth fade-out when changing scenes
- Button press animations

## 📁 Placeholder Elements

### Current Placeholders:
- **Clouds**: White Polygon2D shapes (3 clouds)
- **Trees**: ColorRect trunks + Polygon2D tufts (4 trees)
- **Wobble Stacks**: ColorRect boxes in teetering stacks (2 stacks)
- **Wobble Tower**: ColorRect segments in a tower (1 tower)

### Naming Convention:
- All wobble elements must have "Wobble" in their name
- Placeholder shapes use descriptive names (CloudPlaceholder, TreePlaceholder, etc.)

## 🔧 Customization

### Adjust Wobble Physics
In `main_menu.gd`, modify these variables:
```gdscript
var wobble_strength: float = 2.0      # Overall wobble intensity
var wobble_damping: float = 0.95      # How quickly motion slows (0.9-0.99)
var wobble_spring: float = 0.1         # Spring force strength (0.05-0.2)
```

### Adjust Parallax Speed
```gdscript
var parallax_scroll_speed: float = 20.0  # Pixels per second
```

### Adjust Layer Speeds
In `_setup_parallax()`:
```gdscript
sky_layer.motion_scale = Vector2(0.1, 0.1)      # Slowest
cloud_layer.motion_scale = Vector2(0.3, 0.3)    # Slow
tree_layer.motion_scale = Vector2(0.6, 0.6)     # Medium
foreground_layer.motion_scale = Vector2(1.0, 1.0)  # Fastest
```

## 🎨 Replacing Placeholders with Real Art

### Step 1: Prepare Your Art
- Export sprites as PNG files
- Recommended sizes:
  - Trees: ~100-150px tall
  - Clouds: ~100-200px wide
  - Wobble elements: Match current placeholder sizes

### Step 2: Replace in Scene
1. Open `MainMenu.tscn` in Godot
2. For each placeholder:
   - Select the placeholder node
   - In the Inspector, add a `Sprite2D` or `AnimatedSprite2D` child
   - Load your texture
   - Remove or hide the placeholder ColorRect/Polygon2D
   - Adjust position/scale as needed

### Step 3: Maintain Structure
- **Keep node names** - The script finds wobble elements by name
- **Keep hierarchy** - Parallax layers must remain in ParallaxBackground
- **Keep positions** - Wobble base positions are stored automatically

### Example: Replacing a Tree
```
TreePlaceholder1 (Node2D)
├── Trunk (ColorRect) ← Remove this
├── Tuff (Polygon2D) ← Remove this
└── TreeSprite (Sprite2D) ← Add this, load your tree texture
```

## 🎮 Adding More Wobble Elements

1. Add a Node2D to the ForegroundLayer (or any layer)
2. Name it with "Wobble" in the name (e.g., "WobbleHouse", "WobbleTower")
3. Add your placeholder shapes as children
4. The system will automatically find and animate it!

## 🐛 Troubleshooting

### Wobble elements not moving
- Check that node names contain "Wobble"
- Verify nodes are Node2D type (not Control)
- Check console for initialization messages

### Parallax not scrolling
- Verify ParallaxBackground exists
- Check that layers have motion_scale set
- Ensure `_update_parallax()` is being called in `_process()`

### Buttons not responding
- Check node paths match scene structure
- Verify signals are connected in `_setup_buttons()`
- Check console for error messages

## 📊 Performance

- **Wobble Physics**: Runs every frame, optimized for 60fps
- **Parallax**: Single offset update per frame
- **Transitions**: Tween-based, very efficient

The system is designed to handle 10-20 wobble elements smoothly.

## 🚀 Next Steps

1. **Test the system** - Run the game and verify all animations work
2. **Customize parameters** - Adjust wobble/physics to your preference
3. **Add more placeholders** - Create additional wobble elements
4. **Replace with art** - When ready, swap placeholders for real sprites
5. **Add sound effects** - Integrate audio for button interactions

## 💡 Tips

- **Wobble strength**: Start low (1.0-2.0) and increase if needed
- **Damping**: Higher values (0.95-0.99) = smoother, slower motion
- **Spring**: Lower values (0.05-0.1) = gentler return to base position
- **Parallax speed**: 15-25 pixels/second works well for most cases

The placeholder system is fully functional and ready for your art assets!
