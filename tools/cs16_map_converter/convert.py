#!/usr/bin/env python3
"""Convert locally supplied CS 1.6 BSP30 + WAD3 assets to self-contained DE BSP29."""
import argparse
import hashlib
import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path
from bsp import BSP, ConversionError, bounded_read, entity_bytes, pack, require
from textures import Wads, convert as convert_textures, records
from entities import convert as convert_entities

VERSION = '1.1'


def convert(raw, wads, title, sites=None, replace_missing=False, texture_rules=None):
    bsp = BSP(raw)
    require(len(bsp.lumps[2])>=4, 'Missing texture table')
    count=struct.unpack_from('<i',bsp.lumps[2])[0]
    require(0<count<=2048, 'Invalid texture table')
    referenced={bsp.texinfo[face[4]][8] for face in bsp.faces}
    unused_slots=set(range(count))-referenced
    tex, palettes, textures = convert_textures(bsp.lumps[2], wads, replace_missing, texture_rules, unused_slots)
    require(all(0 <= row[8] < len(textures) for row in bsp.texinfo), 'Texinfo references missing texture')
    rows, layout, changes, warnings = convert_entities(bsp, title, sites)
    replacements = [r for r in textures if r['source'].startswith('generated:')]
    if replacements:
        warnings.append(f'{len(replacements)} missing textures replaced with original procedural industrial materials; these are approximations, not the missing WAD artwork.')
    resized = [r['name'] for r in textures if 'resampled_from' in r]
    if resized:
        warnings.append('WAD texture resolution differs from compiled BSP; art resampled to preserve UV scale: '+', '.join(resized))
    if bsp.entities[0].get('skyname'):
        warnings.append('External GoldSrc skybox images are not included; FPSloppa supplies its sky.')
    if any(row['name'].startswith(('+', '-')) for row in textures):
        warnings.append('Animated texture sequences render as static frames.')
    if any(sum(s != 255 for s in face[5:9]) > 1 for face in bsp.faces):
        warnings.append('Multiple light styles are preserved in data; rendering uses the first baked style.')
    rgb = bsp.lumps[8]
    require(len(rgb) % 3 == 0, 'GoldSrc RGB lighting has incomplete samples')
    faces = bytearray(bsp.lumps[7])
    for i, face in enumerate(bsp.faces):
        offset = face[-1]
        require(offset == -1 or offset >= 0 and offset % 3 == 0, 'Invalid RGB lightmap offset')
        if offset >= 0:
            info = bsp.texinfo[face[4]]
            # BSP compilers store texture extents at float32 precision. Keeping
            # Python's extra precision can add a spurious lightmap row/column.
            f32 = lambda v: struct.unpack('<f', struct.pack('<f', v))[0]
            coords = [[f32(sum(p[a]*info[a+axis*4] for a in range(3))+info[3+axis*4]) for p in bsp.polygon(face)] for axis in range(2)]
            size = math.prod(math.ceil(max(v)/16)-math.floor(min(v)/16)+1 for v in coords)
            styles = sum(s != 255 for s in face[5:9])
            require(size > 0 and styles > 0 and offset+size*styles*3 <= len(rgb), 'Face light samples extend beyond RGB lighting')
            struct.pack_into('<i', faces, i*20+16, offset//3)
    lumps = bsp.lumps.copy()
    lumps[0] = entity_bytes(rows); lumps[2] = tex; lumps[7] = bytes(faces)
    lumps[8] = bytes((r*54+g*183+b*19+128)//256 for r, g, b in struct.iter_unpack('3B', rgb))
    extensions = {'RGBLIGHTING': rgb, 'FSL_PALETTES': palettes, 'FSL_DE': json.dumps(layout, separators=(',', ':'), allow_nan=False).encode()}
    output = pack(lumps, extensions)
    BSP(output, 29)
    preserved = [i for i in range(15) if i not in [0, 2, 7, 8]]
    report = {'converter_version': VERSION, 'source_sha256': hashlib.sha256(raw).hexdigest(), 'sha256': hashlib.sha256(output).hexdigest(), 'bytes': len(output), 'format': 'BSP29 + RGBLIGHTING/FSL_PALETTES/FSL_DE', 'geometry_lumps_preserved': preserved, 'geometry_sha256': {str(i): hashlib.sha256(lumps[i]).hexdigest() for i in preserved}, 'textures': textures, 'used_wads': sorted(wads.used), 'wad_sources': [r for r in wads.sources if r['name'] in wads.used], 'wad_duplicate_names_first_wins': sorted(wads.duplicates), 'layout': layout, 'entities': changes, 'warnings': warnings, 'runtime_validation': 'not run', 'asset_rights': 'Original map and texture rights remain with their authors. No assets are bundled with the converter.'}
    return output, report


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('maps', nargs='+', type=Path)
    p.add_argument('--output', type=Path, help='Output directory (originals are never replaced)')
    p.add_argument('--wad', action='append', default=[], type=Path, help='WAD3 file; repeat; earlier files take priority')
    p.add_argument('--wad-dir', action='append', default=[], type=Path, help='Scan this directory for WAD3 files, without recursion')
    p.add_argument('--replace-missing', action='store_true', help='Generate clearly reported industrial substitutes when a texture has no WAD')
    p.add_argument('--texture-rules', type=Path, help='JSON exact texture name to generated material category; used only for missing textures')
    p.add_argument('--sites', type=Path, help='JSON A/B entity selections and optional GoldSrc min/max/point overrides; single input only')
    p.add_argument('--inspect', action='store_true', help='Print source entities, bomb targets and WAD basenames without converting')
    p.add_argument('--strict', action='store_true', help='Reject any unsupported entity behaviour instead of applying reported fallbacks')
    p.add_argument('--validate', action='store_true', help='Import in updated FPSloppa, check spawns/sites and bake/test bot navigation')
    project_default = next((parent for parent in Path(__file__).resolve().parents if (parent/'project.godot').is_file()), Path.cwd())
    p.add_argument('--project', type=Path, default=project_default, help='Updated FPSloppa source project for --validate')
    p.add_argument('--godot', default='godot', help='Godot executable for --validate')
    args = p.parse_args(argv)
    require(args.inspect or args.output is not None, 'Supply --output DIRECTORY or --inspect')
    require(not args.sites or len(args.maps) == 1, '--sites applies to one input map')
    names = [path.stem.lower() for path in args.maps]
    require(len(set(names)) == len(names), 'Input map basenames collide')
    paths = args.wad.copy()
    for directory in args.wad_dir:
        require(directory.is_dir(), f'WAD directory not found: {directory}')
        paths.extend(sorted((f for f in directory.iterdir() if f.suffix.lower() == '.wad'), key=lambda f: f.name.lower()))
    wads = None if args.inspect else Wads(list(dict.fromkeys(paths)))
    require(not args.texture_rules or args.replace_missing, '--texture-rules requires --replace-missing')
    texture_rules = json.loads(bounded_read(args.texture_rules, 65536)) if args.texture_rules else None
    for source in args.maps:
        raw = bounded_read(source)
        if args.inspect:
            bsp = BSP(raw)
            print(json.dumps({'source': str(source), 'wad_basenames': [s.replace('\\', '/').split('/')[-1] for s in bsp.entities[0].get('wad', '').split(';') if s], 'entities': [{'index': i, **e} for i, e in enumerate(bsp.entities)], 'faces': len(bsp.faces), 'models': len(bsp.models), 'textures': [{'name':n, 'width':w, 'height':h, 'embedded':m is not None} for n,w,h,m,_ in records(bsp.lumps[2])]}, indent=2))
            continue
        require(all(c.isascii() and (c.isalnum() or c in '_-') for c in source.stem) and len(source.stem) <= 55, 'Use a simple ASCII map basename, at most 55 characters')
        name = ('de_' if not source.stem.lower().startswith('de_') else '')+source.stem.lower()+'_fps'
        dest = args.output / (name+'.bsp')
        require(dest.resolve() != source.resolve(), 'Original map cannot be overwritten')
        sites = json.loads(bounded_read(args.sites, 65536)) if args.sites else None
        wads.used.clear()
        output, report = convert(raw, wads, source.stem+' | CS 1.6 conversion', sites, args.replace_missing, texture_rules)
        if args.strict:
            require(not any(not s.startswith('A/B labels') for s in report['warnings']), 'Strict conversion rejected reported fallbacks; run without --strict to inspect the conversion report')
        receipt = dest.with_suffix('.conversion.json')
        require(not dest.exists() or dest.read_bytes() == output, f'Refusing to replace different output: {dest}')
        args.output.mkdir(parents=True, exist_ok=True)
        temporary = dest.with_suffix('.bsp.tmp'); temporary.write_bytes(output); temporary.replace(dest)
        report['output'] = dest.name
        receipt.write_text(json.dumps(report, indent=2)+'\n')
        if args.validate:
            project = args.project.resolve()
            script = project/'tools/cs16_map_converter/validate.gd'
            require((project/'project.godot').is_file() and script.is_file(), '--validate needs an updated FPSloppa source project')
            binary = shutil.which(args.godot) or args.godot
            log = dest.with_suffix('.validation.log')
            report['runtime_validation'] = 'failed'
            try:
                with log.open('w') as stream:
                    check = subprocess.run([binary, '--headless', '--audio-driver', 'Dummy', '--xr-mode', 'off', '--path', str(project), '--log-file', str(dest.with_suffix('.engine.log').resolve()), '--script', str(script), '--', str(dest.resolve())], stdout=stream, stderr=subprocess.STDOUT, timeout=300)
                text = log.read_text()
                if check.returncode == 0 and 'CS_MAP_VALIDATION_PASS' in text and 'ERROR:' not in text:
                    report['runtime_validation'] = 'passed'
            except (OSError, subprocess.SubprocessError):
                receipt.write_text(json.dumps(report, indent=2)+'\n')
                raise
            receipt.write_text(json.dumps(report, indent=2)+'\n')
            require(report['runtime_validation'] == 'passed', f'Runtime validation failed; see {log}. Do not deploy this conversion yet.')
        print(f'{dest} ({len(output):,} bytes); {len(report["warnings"])} reported caveats; validation: {report["runtime_validation"]}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ConversionError, OSError, ValueError, TypeError, OverflowError, struct.error, subprocess.SubprocessError) as exc:
        print('Conversion failed: '+str(exc), file=sys.stderr)
        sys.exit(1)
