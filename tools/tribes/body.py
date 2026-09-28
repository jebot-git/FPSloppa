"""Canonical armour build entry point; execute through Blender MCP."""
from pathlib import Path
p=Path("/home/blux/Documents/FPSloppa/tools/tribes/family.py")
exec(compile(p.read_text(),str(p),"exec"))
