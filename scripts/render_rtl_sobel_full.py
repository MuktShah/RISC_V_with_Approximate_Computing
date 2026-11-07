"""Render a full-image RTL Sobel memory dump and compare it to the golden PNG."""

import sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
rtl = ROOT / "RTL" / "sobel_full"
COUNT, BASE = 254 * 254, 0x10000

def load(path):
    values, address = {}, 0
    for token in path.read_text(encoding="ascii").split():
        if token.startswith("@"):
            address = int(token[1:], 16)
        else:
            values[address] = int(token, 16)
            address += 1
    start = BASE if BASE in values else 0
    return np.array([values[start + index] for index in range(COUNT)], dtype=np.uint32).reshape(254, 254)

dump = Path(sys.argv[1]) if len(sys.argv) == 2 else rtl / "sobel_rtl_output.mem"
result = load(dump)
Image.fromarray(np.clip(result, 0, 255).astype(np.uint8)).save(rtl / "rtl_output_hoeraa.png")
golden = load(rtl / "golden_output.mem")
error = result.astype(np.int64) - golden.astype(np.int64)
print(f"Wrote {rtl / 'rtl_output.png'}; maximum stored magnitude = {result.max()}")
print(f"Mismatched pixels: {np.count_nonzero(error)}; maximum absolute error: {np.abs(error).max()}")
if np.any(error):
    raise SystemExit("RTL output differs from the exact golden result")
