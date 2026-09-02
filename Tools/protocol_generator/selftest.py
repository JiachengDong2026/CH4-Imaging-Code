#!/usr/bin/env python3
"""Dependency-free checks for the frozen stage 0 definitions."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

from generate import ROOT, crc16_ccitt_false, load_definition, validate


def main() -> int:
    protocol = load_definition(ROOT / "Shared/protocol.yaml")
    registers = load_definition(ROOT / "Shared/register_map.yaml")
    validate(protocol, registers)
    assert crc16_ccitt_false(b"123456789") == 0x29B1
    assert protocol["fused_point"]["size"] == 48

    vectors = json.loads(
        (ROOT / "Shared/test_vectors/protocol_vectors.json").read_text(encoding="utf-8")
    )["vectors"]
    for vector in vectors:
        frame = bytes.fromhex(vector["frame_hex"])
        assert frame[:2] == b"\xA5\x5A"
        payload_length = int.from_bytes(frame[9:11], "little")
        assert len(frame) == payload_length + 13
        crc_ok = crc16_ccitt_false(frame[2:-2]) == int.from_bytes(frame[-2:], "little")
        assert crc_ok is vector["valid"], vector["name"]

    generator = ROOT / "Tools/protocol_generator/generate.py"
    result = subprocess.run([sys.executable, str(generator), "--check"], cwd=ROOT)
    assert result.returncode == 0
    print(f"shared-protocol-selftest: PASS ({len(vectors)} fixed frames, CRC 0x29B1)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

