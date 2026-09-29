"""Blender MCP entry point for the current reference-led vehicle designs."""
from pathlib import Path
VEHICLE_PROJECT = globals().get("VEHICLE_PROJECT", (Path(__file__).resolve().parents[2] if '__file__' in globals() else Path('/home/blux/Documents/FPSloppa')))
VEHICLE_KINDS = ['lpc', 'hpc']
_builder = Path(VEHICLE_PROJECT) / "tools/tribes/vehicle_models.py"
exec(compile(_builder.read_text(), str(_builder), "exec"))
