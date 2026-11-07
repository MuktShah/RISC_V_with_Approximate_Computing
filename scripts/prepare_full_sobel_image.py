"""Convert Cameraman BMP into memory contents for the full RTL Sobel run."""

from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
rtl = ROOT / "RTL" / "sobel_full"
image = np.asarray(Image.open(ROOT / "Python" / "cameraman.bmp").convert("L"), dtype=np.uint8)
if image.shape != (256, 256):
    raise ValueError(f"Expected a 256x256 image; received {image.shape}")
rtl.mkdir(exist_ok=True)
with (rtl / "data.mem").open("w", encoding="ascii", newline="\n") as file:
    for value in image.flat:
        file.write(f"{int(value):08x}\n")

pixels = image.astype(np.int32)
gx = (pixels[:-2, 2:] - pixels[:-2, :-2]) + 2 * (pixels[1:-1, 2:] - pixels[1:-1, :-2]) + (pixels[2:, 2:] - pixels[2:, :-2])
gy = (pixels[2:, :-2] - pixels[:-2, :-2]) + 2 * (pixels[2:, 1:-1] - pixels[:-2, 1:-1]) + (pixels[2:, 2:] - pixels[:-2, 2:])
golden = (np.abs(gx) + np.abs(gy)).astype(np.uint32)
with (rtl / "golden_output.mem").open("w", encoding="ascii", newline="\n") as file:
    for value in golden.flat:
        file.write(f"{int(value):08x}\n")
Image.fromarray(np.clip(golden, 0, 255).astype(np.uint8)).save(rtl / "golden_output.png")
(rtl / "image_info.txt").write_text(
    "input=cameraman.bmp\ninput_dimensions=256x256\ninput_base_byte_address=0x00000\n"
    "output_dimensions=254x254\noutput_base_byte_address=0x40000\n",
    encoding="ascii",
)
print("Wrote 65,536 input pixels and 64,516 golden Sobel outputs")
