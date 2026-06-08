#!/usr/bin/env python3
"""
Fix Obsidian-style image embeds in markdown.

  Find:    ![[Pasted image 20260601123540.png]]
  Replace: ![Screenshot](img/Pasted%20image%2020260601123540.png)

Yes, Claude helped me out.
"""

import re
import sys

def fix_markdown(filepath: str) -> None:
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    def replace_embed(m):
        filename = m.group(1)
        encoded = filename.replace(" ", "%20")
        return f"![Screenshot](img/{encoded})"

    content = re.sub(r'!\[\[([^\]]+)\]\]', replace_embed, content)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Done. Updated: {filepath}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <file.md>")
        sys.exit(1)
    fix_markdown(sys.argv[1])