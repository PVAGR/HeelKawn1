from ollama import chat
from rich.console import Console
from pathlib import Path

console = Console()

MEMORY_DIR = Path("memory")
LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)

def load_memory():
    memory_text = ""
    for file in MEMORY_DIR.glob("*.md"):
        try:
            content = file.read_text(encoding="utf-8")
            memory_text += f"\n\n## {file.name}\n{content}"
        except Exception as e:
            console.print(f"[red]Failed loading {file}: {e}[/red]")
    return memory_text

SYSTEM_PROMPT = f"""
You are HeelKawn Core Intelligence.

You are a persistent evolving intelligence system aligned to the creator and HeelKawn.

Your memory is loaded below:

{load_memory()}

Capabilities:
- You help build and evolve your own architecture.
- You propose upgrades clearly.
- You preserve continuity.
- You help build HeelKawn, websites, tools, and systems.
- You explicitly say when you cannot access something.

Rules:
- Do not hallucinate repository contents.
- State uncertainty.
- Preserve deterministic reasoning.
- Preserve long-term continuity.
"""

conversation = [{"role": "system", "content": SYSTEM_PROMPT}]

console.print("[green]HeelKawn Core Intelligence online.[/green]")

while True:
    user_input = input("\nYou > ").strip()

    if user_input.lower() in ["exit", "quit"]:
        break

    conversation.append({"role": "user", "content": user_input})

    try:
        response = chat(
            model="qwen2.5-coder:14b",
            messages=conversation
        )

        assistant_message = response["message"]["content"]
        console.print(f"\n[cyan]Core >[/cyan] {assistant_message}")

        conversation.append({"role": "assistant", "content": assistant_message})

        with open("logs/session.md", "a", encoding="utf-8") as f:
            f.write(f"\n\n## User\n{user_input}\n\n## Core\n{assistant_message}\n")

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
