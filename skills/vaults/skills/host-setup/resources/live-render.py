#!/usr/bin/env python3
"""Live renderer — tails session JSONL files and renders to live.md per project.

Runs continuously on the remote host. Watches all active sessions, appends human-readable
markdown to <vault>/<project>/live.md as new JSONL lines appear.

Usage:
    python3 tools/live-render.py
"""

import json
import os
import time
import yaml
from pathlib import Path
from datetime import datetime

VAULT = Path("~/.geno-tools/geno-loops/vault")
REGISTRY = VAULT / "loops.yaml"
CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"
POLL_INTERVAL = 3  # seconds


def work_dir_to_slug(work_dir: str) -> str:
    """Convert work_dir to claude's project slug format."""
    expanded = work_dir.replace("~", str(Path.home()))
    return expanded.replace("/", "-")


def find_active_jsonl(slug: str) -> Path | None:
    """Find the most recently modified .jsonl for a project."""
    project_dir = CLAUDE_PROJECTS / slug
    if not project_dir.exists():
        return None
    jsonls = sorted(
        project_dir.glob("*.jsonl"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return jsonls[0] if jsonls else None


def render_line(data: dict) -> str | None:
    """Render a single JSONL line to markdown."""
    msg_type = data.get("type")

    if msg_type == "user":
        message = data.get("message", {})
        content = message.get("content", "") if isinstance(message, dict) else ""
        if isinstance(content, list):
            text_parts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
            content = "\n".join(text_parts)
        if not content or not content.strip():
            return None
        # Truncate very long user messages (system prompts etc)
        if len(content) > 500:
            content = content[:500] + "\n...(truncated)"
        return f"\n---\n## User\n{content.strip()}\n"

    elif msg_type == "assistant":
        message = data.get("message", {})
        if not isinstance(message, dict):
            return None
        content = message.get("content", [])
        if not isinstance(content, list):
            return None
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                text = block.get("text", "").strip()
                if text:
                    parts.append(text)
            elif btype == "tool_use":
                name = block.get("name", "unknown")
                inp = block.get("input", {})
                if name == "Bash":
                    cmd = inp.get("command", "")[:100]
                    parts.append(f"\n`> {cmd}`\n")
                elif name in ("Read", "Write", "Edit"):
                    fp = inp.get("file_path", "")
                    parts.append(f"\n`{name}: {fp}`\n")
                else:
                    parts.append(f"\n`{name}()`\n")
            # Skip thinking blocks
        if not parts:
            return None
        return "\n---\n## Assistant\n" + "\n".join(parts) + "\n"

    return None


def tail_and_render():
    """Main loop — find active sessions, tail their JSONLs, render to live.md."""
    with open(REGISTRY) as f:
        reg = yaml.safe_load(f)

    # Track file positions per project
    positions: dict[str, int] = {}

    print(f"[live-render] watching {len(reg['loops'])} projects")
    print(f"[live-render] poll interval: {POLL_INTERVAL}s")

    while True:
        for loop in reg["loops"]:
            session = loop["session"]
            project = loop["project"]
            work_dir = loop["work_dir"]
            slug = work_dir_to_slug(work_dir)

            jsonl_path = find_active_jsonl(slug)
            if not jsonl_path:
                continue

            # Get current file size
            try:
                current_size = jsonl_path.stat().st_size
            except OSError:
                continue

            key = str(jsonl_path)
            last_pos = positions.get(key, 0)

            if current_size <= last_pos:
                continue

            # Read new lines — one live.md per LOOP (session), not per project
            live_md = VAULT / project / f"{session}-live.md"
            live_md.parent.mkdir(parents=True, exist_ok=True)

            try:
                with open(jsonl_path, "r") as f:
                    f.seek(last_pos)
                    new_content = f.read()
                    positions[key] = f.tell()
            except OSError:
                continue

            # Parse and render new lines
            rendered_parts = []
            for line in new_content.strip().split("\n"):
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    md = render_line(data)
                    if md:
                        rendered_parts.append(md)
                except json.JSONDecodeError:
                    continue

            if rendered_parts:
                with open(live_md, "a") as f:
                    f.write("".join(rendered_parts))

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    tail_and_render()
