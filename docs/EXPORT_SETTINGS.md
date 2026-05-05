# HeelKawn - Godot Export Settings Guide

**Use these settings for EVERY export to ensure optimal builds**

---

## 🎯 **RECOMMENDED EXPORT SETTINGS**

### **Windows Desktop (Primary Platform)**

#### **Basic Settings**
```
Debug → Export With Debug: OFF
Debug → Export With Symbols: OFF
Application → Name: HeelKawn
Application → Version: 1.0.0
Application → Icon: [Your game icon]
```

#### **Features**
```
☑ 3D
☐ 2D (unchecked - HeelKawn uses 3D viewport)
☑ Advanced API
```

#### **Architecture**
```
Architecture: x86_64
```

#### **Texture Format**
```
BPTC: ☑
ETC: ☐
S3TC: ☑
```

#### **Custom Template**
```
Use Custom Template: ☐ (unchecked - use default)
```

#### **Binary Format**
```
Binary Format: ☑ Binary (faster loading, harder to decompile)
```

#### **File Filtering**
```
Include filter: *.gd, *.tscn, *.tres, *.png, *.jpg, *.ogg, *.mp3
Exclude filter: *.git*, *.qwen*, tools/*, docs/*
```

---

## 📦 **EXPORT WORKFLOW**

### **Step-by-Step**

1. **Open Export Window**
   ```
   Project → Export (or Ctrl+Shift+E)
   ```

2. **Add Platform** (if not already added)
   ```
   Add... → Windows Desktop
   ```

3. **Configure Settings** (see above)

4. **Export Project**
   ```
   Click "Export Project" button
   Choose location: C:\Users\user\Documents\GitHub\HeelKawn1\exports\
   Filename: HeelKawn_v1.0_Windows.exe
   Click "Save"
   ```

5. **Wait for Export** (30-60 seconds)

6. **Test Exported Build**
   ```
   Navigate to exports folder
   Double-click HeelKawn_v1.0_Windows.exe
   Play for 5 minutes
   Verify no errors in console
   ```

---

## 🖥️ **MULTIPLE PLATFORMS**

### **Recommended Platforms to Support**

| Platform | Priority | File Format | Size Estimate |
|----------|----------|-------------|---------------|
| **Windows** | ✅ Required | `.exe` or `.zip` | ~100-150 MB |
| **Linux** | ⚠️ Optional | `.x86_64` | ~100-150 MB |
| **macOS** | ⚠️ Optional | `.zip` (app bundle) | ~100-150 MB |
| **Web (HTML5)** | ❌ Not recommended | `.html` | N/A |

> **Note:** Web export NOT recommended for HeelKawn due to:
> - Large memory requirements
> - Complex simulation may lag in browser
> - File I/O for saves problematic in browser

---

## ⚙️ **ADVANCED SETTINGS**

### **Optimizations**

#### **Shader Mode**
```
Shader Mode: SPIR-V (better compatibility)
```

#### **Vertex Format**
```
Vertex Format: Use Vertex Arrays (faster loading)
```

#### **Resources**
```
Pack Mode: Pack all resources into PCK
Compress: ☑ Deflate (good compression, fast decompression)
```

---

## 🐛 **TROUBLESHOOTING**

### **Export Fails**

**Error: "Export template not found"**
```
Solution: Download export templates from Godot website
1. Go to godotengine.org/download
2. Download "Export Templates" for 4.6.2
3. Install templates
4. Restart Godot
```

**Error: "Missing dependencies"**
```
Solution: Check for missing autoload scripts
1. Project → Project Settings → Autoload
2. Verify all autoloads point to existing files
3. Fix any broken paths
```

**Export hangs at 99%**
```
Solution: Wait longer (large projects take time)
If stuck > 5 minutes:
1. Cancel export
2. Close Godot
3. Reopen and try again
4. Check disk space
```

---

### **Exported Build Crashes**

**Crashes on launch**
```
Check:
1. Run from command prompt to see errors
2. Check Output panel in Godot before export
3. Verify all assets load correctly
4. Test in Godot first (F5)
```

**Crashes during gameplay**
```
Check:
1. Godot console output (before export)
2. Memory usage (Godot profiler)
3. Infinite loops in code
4. Resource loading issues
```

---

### **Build Too Large**

**If > 200MB:**
```
1. Check for large assets (textures, audio)
2. Compress textures (Project Settings → Texture Import)
3. Use OGG for audio (not WAV)
4. Exclude unnecessary files in export filter
```

---

## 📊 **FILE SIZE OPTIMIZATION**

### **Texture Compression**
```
Recommended settings:
- Compression Mode: VRAM Compressed
- Compress: ☑
- Lossless: ☐ (unchecked for smaller size)
```

### **Audio Compression**
```
Recommended settings:
- Format: OGG Vorbis
- Bitrate: 128 kbps (good quality, small size)
- Max Channels: 2 (stereo)
```

---

## ✅ **PRE-EXPORT CHECKLIST**

Before every export:

- [ ] All code compiles without errors
- [ ] No `print()` debug statements in final build
- [ ] Version number updated
- [ ] Tested in Godot editor (F5) for 10 minutes
- [ ] No errors in Output panel
- [ ] All autoloads load correctly
- [ ] Export templates installed
- [ ] Enough disk space (> 500MB free)

---

## 🚀 **POST-EXPORT CHECKLIST**

After every export:

- [ ] Run exported build (NOT from Godot)
- [ ] Play for 5 minutes minimum
- [ ] Test all major features
- [ ] Check for console errors
- [ ] Verify saves work (if applicable)
- [ ] Check file size
- [ ] Test on different computer (optional but recommended)

---

## 📁 **RECOMMENDED FOLDER STRUCTURE**

```
HeelKawn1/
├── exports/
│   ├── v1.0/
│   │   ├── HeelKawn_v1.0_Windows.exe
│   │   ├── HeelKawn_v1.0_Linux.x86_64
│   │   └── HeelKawn_v1.0_Mac.zip
│   ├── v1.1/
│   │   └── ...
│   └── latest/
│       └── [symlinks to latest version]
├── project.godot
├── autoloads/
├── scripts/
└── ...
```

---

## 🔧 **COMMAND LINE EXPORT** (Advanced)

For automated builds:

```bash
# Windows
godot --headless --export-release "Windows Desktop" exports/HeelKawn_v1.0_Windows.exe

# Linux
godot --headless --export-release "Linux/X11" exports/HeelKawn_v1.0_Linux.x86_64

# macOS
godot --headless --export-release "macOS" exports/HeelKawn_v1.0_Mac.zip
```

> **Note:** Replace `godot` with full path to Godot executable

---

## 📝 **VERSION NUMBERING IN EXPORTS**

**File naming convention:**
```
HeelKawn_v[MAJOR].[MINOR].[PATCH]_[PLATFORM].[EXT]

Examples:
HeelKawn_v1.0.0_Windows.exe
HeelKawn_v1.0.1_Linux.x86_64
HeelKawn_v1.1.0_Mac.zip
HeelKawn_v2.0.0_Windows.exe
```

---

**Use these settings for consistent, optimized builds every time.**

For questions about export issues, check the Troubleshooting section or consult Godot documentation.
