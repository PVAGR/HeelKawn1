# Godot 4.x GDScript Error Fix - AI Prompt Template

**Copy and paste this prompt into any AI coding assistant (ChatGPT, Claude, Cursor, GitHub Copilot, etc.) when you need help fixing Godot compilation errors.**

---

## 📋 **PROMPT TO COPY:**

```
Act as a senior Godot 4.x GDScript engine expert. I'm providing a compilation error log from my project. Your task is to:

1. 🔍 **Identify the exact root cause** triggering the entire error cascade.

2. 🛠️ **Provide the precise fix** for the offending file/line. If possible, output the corrected code snippet. If not, give exact step-by-step editor instructions.

3. 📉 **Explain in 1-2 sentences** why this single fix automatically resolves all downstream `Could not resolve script` and `Failed to compile depended scripts` errors.

4. ⚙️ **Recommend 2-3 Godot Editor settings** to enforce consistent indentation and prevent this issue in future projects.

⚠️ **Constraints:**
- GDScript strictly requires consistent indentation (4 spaces by default). Mixed tabs/spaces break the parser.
- Do NOT rewrite logic, change variable names, or refactor unrelated code. Only fix the parsing/indentation issue.
- Keep the response concise, technical, and immediately actionable.
- If you need the full content of the problematic file to output a corrected version, ask for it. Otherwise, provide line-specific fix instructions.

---

**Here is the error log:**

[PASTE YOUR FULL GODOT ERROR LOG HERE]

---

**Respond with a structured, step-by-step fix. Use proper code blocks for any snippets.**
```

---

## 📖 **HOW TO USE THIS PROMPT:**

### **Step 1: Copy the Prompt**
- Copy everything between the `---` lines above (including the instructions)

### **Step 2: Paste Your Error Log**
- Replace `[PASTE YOUR FULL GODOT ERROR LOG HERE]` with your actual Godot error output
- Include ALL errors (even the cascade ones)

### **Step 3: Paste into AI**
- Open ChatGPT, Claude, Cursor, or any AI coding assistant
- Paste the complete prompt
- Wait for the structured response

### **Step 4: Apply the Fix**
- Follow the exact line-by-line instructions
- The AI should tell you:
  - Which file has the error
  - Which line number
  - What character/whitespace is wrong
  - The corrected code snippet

---

## 🎯 **WHAT TO EXPECT IN THE RESPONSE:**

A good AI response should include:

### **1. Root Cause Analysis**
```
🔍 ROOT CAUSE:
File: autoloads/WorldMemory.gd
Line: 1685
Issue: Tab character (0x09) found at column 1, expected 4 spaces
```

### **2. Exact Fix**
```gdscript
# ❌ BEFORE (line 1685):
	var text: String = ""  # ← starts with TAB

# ✅ AFTER (line 1685):
    var text: String = ""  # ← starts with 4 SPACES
```

### **3. Cascade Explanation**
```
📉 WHY THIS FIXES ALL ERRORS:
WorldMemory.gd is an autoload singleton. If it fails to parse, ALL scripts 
that reference it (directly or indirectly) will fail with "Could not resolve 
script" errors. Fixing the autoload resolves the entire dependency cascade.
```

### **4. Prevention Settings**
```
⚙️ GODOT EDITOR SETTINGS:
1. Editor → Editor Settings → Text Editor → Indent:
   - Type: Spaces
   - Size: 4
2. Enable "Auto Indent" checkbox
3. Install "EditorConfig" plugin for project-wide standards
```

---

## 🚨 **COMMON GODOT COMPILE ERRORS THIS PROMPT FIXES:**

| Error Pattern | Typical Cause |
|---------------|---------------|
| `Used tab character for indentation` | Mixed tabs/spaces in file |
| `Could not resolve script "res://autoloads/..."` | Autoload has parse error |
| `Failed to compile depended scripts` | Parent script failed to compile |
| `Parse Error: Expected closing "]"` | Syntax error (often whitespace-related) |
| `Identifier not declared` | Script didn't load due to parse error |

---

## 💡 **PRO TIPS:**

1. **Always include ALL errors** - Even the cascade ones help AI understand the scope
2. **Mention Godot version** - Add "Godot 4.6.2" at the top if relevant
3. **Include file path** - If you know which file, mention it
4. **Ask for binary-safe fix** - If tabs are the issue, ask AI to "replace all tab bytes (0x09) with 4 spaces"

---

## 📁 **FILE LOCATION:**

This prompt template is saved at:
```
C:\Users\user\Documents\GitHub\HeelKawn1\docs\GODOT_ERROR_FIX_PROMPT.md
```

**Bookmark this file** for future Godot debugging sessions!

---

**Last Updated:** May 5, 2026  
**Tested With:** ChatGPT-4, Claude 3.5, Cursor AI  
**Godot Version:** 4.x series
