#!/usr/bin/env python3
"""Import the user's verified HITRAN waveform into this self-contained project.

Only reads the previously tested DILA project. All writes stay below this
project's FPGA/data directory, as required by Docs/需求.md.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import shutil


ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE_ROOT = pathlib.Path(r"E:\Documents\Vivado\DILA_260823")
SOURCE_MEM = SOURCE_ROOT / "fpga" / "sim" / "sim_ch4_adc.mem"
SOURCE_META = SOURCE_ROOT / "tools" / "spectroscopy" / "generated" / "metadata.json"
OUTPUT_DIR = ROOT / "FPGA" / "data"
OUTPUT_MEM = OUTPUT_DIR / "ch4_hitran_5000ppm.mem"
OUTPUT_META = OUTPUT_DIR / "ch4_hitran_5000ppm.json"


def main() -> int:
    if not SOURCE_MEM.is_file() or not SOURCE_META.is_file():
        raise SystemExit("找不到已验证的 DILA HITRAN 波形或元数据。")
    samples = SOURCE_MEM.read_text(encoding="ascii").splitlines()
    if len(samples) != 12_800 or any(len(value.strip()) != 4 for value in samples):
        raise SystemExit("旧波形不是预期的 12800 × 16-bit HEX 数据。")
    metadata = json.loads(SOURCE_META.read_text(encoding="utf-8"))
    required = {
        "spectral_source": "HITRANonline via official HAPI",
        "sample_rate_hz": 25_600_000,
        "samples_per_scan": 12_800,
        "scan_frequency_hz": 2_000.0,
        "modulation_frequency_hz": 200_000.0,
    }
    for key, expected in required.items():
        if metadata.get(key) != expected:
            raise SystemExit(f"元数据 {key}={metadata.get(key)!r}，预期 {expected!r}。")
    raw = SOURCE_MEM.read_bytes()
    metadata["source_project"] = str(SOURCE_ROOT).replace("\\", "/")
    metadata["source_sha256"] = hashlib.sha256(raw).hexdigest()
    metadata["project_role"] = "stage-1 FPGA ROM input; simulated concentration only"
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE_MEM, OUTPUT_MEM)
    OUTPUT_META.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"imported {len(samples)} verified samples, sha256={metadata['source_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

