#!/usr/bin/env python3
"""Extracts the embedded gateway server.dart from docker_service.dart: extract_server.py <out.dart>"""
import re, sys, pathlib
src = pathlib.Path(__file__).resolve().parents[2].joinpath('lib/services/external/docker_service.dart').read_text()
m = re.search(r"File\('\$_vaultPath/gateway/server\.dart'\);\s*await server\.writeAsString\(r'''\n(.*?)\n'''\);", src, re.S)
if not m:
    sys.exit('server.dart block not found')
pathlib.Path(sys.argv[1]).write_text(m.group(1) + '\n')
