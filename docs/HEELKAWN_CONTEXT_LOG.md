# HeelKawn — context log (standard format)

Use this **header at the top of every message** you paste between AIs (**ChatGPT**, **DeepSeek**, **Cursor**, or the **human creator**). There is **no separate Microsoft Copilot role** in the workflow: **Cursor** covers implementation, integration, and repo-side review that previously might have been split elsewhere.

---

## [HEELKAWN CONTEXT LOG] — required fields

```
[HEELKAWN CONTEXT LOG]

FOR: <Which AI or audience this message is intended for>
FROM: <Which AI or human originated this>
ROLE OF SENDER: <Lore Authority | Brain/Soul | Coder | Integrator | Creator>
PURPOSE: <Why this message exists>
CANON STATUS: <Canon | Draft | Proposal | Question | Informational>
DEPENDENCIES: <Earlier lore, systems, or doc IDs this relies on, or "None">
```

Then the **body** of the message (lore, spec, code request, status).

---

## Why this works

- Reduces silent contradictions and “who said what” confusion.  
- Preserves decision lineage across tools.  
- Optional: append only rows marked **CANON STATUS: Canon** to `docs/HEELKAWN_CANON_LOG.md` as permanent world record.

---

## Examples

**Creator → Cursor:** FOR Cursor, FROM Creator, ROLE Creator, PURPOSE direction or implementation request, CANON Proposal, DEPENDENCIES theme / spec.  

**Cursor → ChatGPT:** FOR ChatGPT, FROM Cursor, ROLE Integrator, PURPOSE translate or validate lore against gameplay, CANON per handoff, DEPENDENCIES HEELKAWN_STATE / CONTEXT LOG.  

**ChatGPT → DeepSeek:** FOR DeepSeek, FROM ChatGPT, ROLE Brain/Soul, PURPOSE narrative → system requirements, CANON per handoff, DEPENDENCIES moral/consequence frame.  

**DeepSeek → Cursor:** FOR Cursor, FROM DeepSeek, ROLE Coder/Integrator, PURPOSE implement in Godot, CANON per handoff, DEPENDENCIES approved spec.  

**Cursor → all (status):** FOR ChatGPT, DeepSeek, Creator, FROM Cursor, ROLE Integrator, PURPOSE implementation state, CANON Informational, DEPENDENCIES None.  

(Cursor in-repo: still obey `docs/HEELKAWN_STATE.md` and do not invent lore; **ROLE** and **CANON** describe the *source* of the request, not permission to add narrative without creator input.)
