# HeelKawn - Release Checklist

**Use this checklist before EVERY release to itch.io**

---

## ✅ **PRE-RELEASE CHECKLIST**

### **Code & Features**
- [ ] All features for this version are complete
- [ ] No `TODO` or `FIXME` comments in critical code paths
- [ ] Git repository is clean (no uncommitted changes)
- [ ] Version number updated in code (if applicable)
- [ ] All new features documented in `CHANGELOG.md`

### **Testing**
- [ ] Game launches without errors
- [ ] Play for 10 minutes at 1x speed
- [ ] Play for 10 minutes at 26x speed
- [ ] Play for 5 minutes at 100x speed
- [ ] Test all F10 menu options (#40-46, #70-75)
- [ ] Test incarnation mode (press P)
- [ ] Test clickable death notifications
- [ ] Test knowledge stone right-click reading
- [ ] Test dynasty tree UI
- [ ] Verify no crashes in Output panel

### **Performance**
- [ ] FPS stays above 55 at 1x speed
- [ ] FPS stays above 35 at 26x speed
- [ ] No memory leaks (check Godot profiler)
- [ ] No infinite loops or freezes

### **UI/UX**
- [ ] All text is readable (no overflow)
- [ ] Buttons respond to clicks
- [ ] Notifications fade properly
- [ ] Biography dialogs can be closed
- [ ] F10 menu opens and closes

### **Documentation**
- [ ] `CHANGELOG.md` updated with this version's changes
- [ ] `README.md` updated if features changed
- [ ] `docs/PLAYER_GUIDE.md` updated if controls changed
- [ ] Version tag ready (e.g., `v1.0`, `v1.1`)

---

## 📦 **EXPORT CHECKLIST**

### **Godot Export Settings**
- [ ] Open Project → Export
- [ ] Select **Windows Desktop** platform
- [ ] Set **Debug Mode** = OFF (release build)
- [ ] Set **Architecture** = x86_64
- [ ] Click **Export Project**
- [ ] Name file: `HeelKawn_v1.0_Windows.zip` (or `.exe`)
- [ ] Repeat for Mac/Linux if supporting those platforms

### **Post-Export Testing**
- [ ] Run exported build (NOT from Godot editor)
- [ ] Play for 5 minutes
- [ ] Verify no console errors
- [ ] Verify all features work in exported build
- [ ] Check file size (should be < 200MB for web-friendly)

---

## 🌐 **ITCH.IO UPLOAD CHECKLIST**

### **Prepare Upload**
- [ ] Log into itch.io
- [ ] Go to your game page → "Edit Game"
- [ ] Click "Upload new files" or "Add new file"

### **Upload Files**
- [ ] Upload Windows build (`.exe` or `.zip`)
- [ ] Upload Mac build (if applicable)
- [ ] Upload Linux build (if applicable)
- [ ] Set **primary** platform (Windows)
- [ ] Set **kind** = "HTML5" or "Upload" (for downloads)

### **Write Release Notes**
- [ ] Title: "HeelKawn v1.0 - [Subtitle]"
- [ ] Write what's new (use `CHANGELOG.md`)
- [ ] Mention any known issues
- [ ] Thank players for support
- [ ] Add screenshots if changed

### **Publish**
- [ ] Click "Save & Publish"
- [ ] Verify page shows new version
- [ ] Check download links work
- [ ] Test download on different computer (optional)

---

## 📢 **POST-RELEASE**

### **Community**
- [ ] Post in itch.io community tab
- [ ] Share on Twitter/social media
- [ ] Update Discord (if you have one)
- [ ] Respond to early comments

### **Git**
- [ ] Create Git tag: `git tag v1.0`
- [ ] Push tag: `git push origin v1.0`
- [ ] Create GitHub Release from tag
- [ ] Attach exported build to GitHub Release

### **Monitor**
- [ ] Watch for bug reports (first 48 hours)
- [ ] Check itch.io analytics (downloads, views)
- [ ] Read player feedback
- [ ] Note bugs for next patch

---

## 🔄 **FOR UPDATES (v1.1, v1.2, etc.)**

### **Additional Steps**
- [ ] Compare with previous version (what changed?)
- [ ] Test save compatibility (if applicable)
- [ ] Mention if saves are compatible in notes
- [ ] Upload as NEW files (don't overwrite old)
- [ ] Mark which is "latest" version
- [ ] Update version in `CHANGELOG.md`

---

## 📊 **VERSION NUMBERING GUIDE**

Use **Semantic Versioning**: `MAJOR.MINOR.PATCH`

| Type | When to Use | Example |
|------|-------------|---------|
| **PATCH** (v1.0.1) | Bug fixes only, no new features | Fixed crash on death |
| **MINOR** (v1.1) | Small features, polish | Added 6 knowledge types |
| **MAJOR** (v2.0) | Big features, new systems | Added Phase 7 endgame |

---

## 🐛 **HOTFIX PROCEDURE** (Critical Bug)

If you find a game-breaking bug after release:

1. **Fix immediately** in code
2. **Test fix** thoroughly (30 min playtest)
3. **Export new build** (v1.0.1, v1.1.1, etc.)
4. **Upload to itch.io** ASAP
5. **Post announcement**: "Hotfix v1.0.1 released - fixes [issue]"
6. **Update CHANGELOG.md**

---

## ✅ **FIRST RELEASE (v1.0) SPECIFIC**

### **Before First Upload**
- [ ] Write compelling game description
- [ ] Take 3-5 screenshots
- [ ] Create cover image (recommended: 630x354px)
- [ ] Set price (or "Free")
- [ ] Add tags: `simulation`, `colony`, `deterministic`, `story-rich`
- [ ] Write "About" section
- [ ] Set system requirements (Windows 10+, 2GB RAM)

### **First Release Notes Template**
```
🎉 HeelKawn v1.0 - Initial Release!

After [X months/years] of development, HeelKawn is finally here!

**What is HeelKawn?**
A deterministic colony simulation where every pawn tells a story, 
every settlement has legends, and knowledge is preserved in stone.

**Features:**
✅ Full simulation with 18 knowledge types
✅ Text-rich storytelling (biographies, legends, chronicles)
✅ Interactive knowledge stones (right-click to read)
✅ Dynasty tracking with visual family tree
✅ Endgame goals (legacy score, succession)
✅ Incarnation mode (UI hides for immersion)
✅ Grudge & gossip systems
✅ Avoidance AI

**Known Issues:**
- [List any minor bugs]

**How to Play:**
See docs/PLAYER_GUIDE.md for complete instructions.

**Thank you!**
Thanks to everyone who supported this project. Your feedback 
shapes future updates!
```

---

## 📝 **QUICK REFERENCE**

**Export Path in Godot:**
```
Project → Export → [Select Platform] → Export Project
```

**itch.io Upload URL:**
```
https://itch.io/game/[YOUR_GAME_ID]/edit
```

**Git Tag Commands:**
```bash
git tag v1.0
git push origin v1.0
```

**Recommended File Naming:**
```
HeelKawn_v1.0_Windows.exe
HeelKawn_v1.0_Mac.zip
HeelKawn_v1.0_Linux.zip
```

---

**Use this checklist for EVERY release to ensure quality and consistency.**
