"""Convert supplied PNGs to the existing Quiet Cove embedded portrait format."""

import argparse
import base64
import hashlib
import json
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[1]
SUPPORTED_SPECIES = {
    "floppa", "chipichapa", "bobrito", "trippitroppi", "bombombini",
    "lirili", "chimpanzini", "frigocamelo", "lavacca", "verity",
}


def rle(values):
    result = bytearray()
    previous, count = None, 0
    for value in values:
        if value != previous or count == 255:
            if count:
                result.extend((count, previous))
            previous, count = value, 1
        else:
            count += 1
    if count:
        result.extend((count, previous))
    return base64.b64encode(result).decode("ascii")


def encode(path):
    with Image.open(path) as opened:
        original = opened.convert("RGBA")
    image = original.copy()
    image.thumbnail((320, 320), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (320, 320), (0, 0, 0, 0))
    canvas.paste(image, ((320 - image.width) // 2, (320 - image.height) // 2))
    rgb = canvas.convert("RGB").quantize(
        colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    palette = rgb.getpalette()
    colors = [
        palette[i] | palette[i + 1] << 8 | palette[i + 2] << 16 | 255 << 24
        for i in range(0, len(palette), 3)
    ]
    source = (
        f"-- Supplied {path.stem} PNG; embedded RGB palette/RLE and resized alpha.\n"
        "return {\n    Width=320, Height=320,\n    Palette={"
        + ",".join(map(str, colors))
        + "},\n"
        + f'    Pixels="{rle(rgb.getdata())}",\n'
        + f'    Alphas="{rle(canvas.getchannel("A").getdata())}",\n}}\n'
    )
    return source, {
        "species": path.stem,
        "input": path.name,
        "input_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "original_size": list(original.size),
        "embedded_size": [320, 320],
        "has_transparency": canvas.getchannel("A").getextrema()[0] < 255,
        "module_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=PROJECT / "assets" / "portraits")
    parser.add_argument("--output", type=Path, default=PROJECT / "src" / "client" / "CatchArtData")
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    if not args.input.is_dir():
        parser.error(f"PNG folder does not exist: {args.input}")
    paths = sorted(p for p in args.input.iterdir() if p.suffix.lower() == ".png")
    invalid = [p.name for p in paths if p.stem not in SUPPORTED_SPECIES]
    if invalid:
        parser.error("Unknown fish ID in PNG filename: " + ", ".join(invalid))
    if not paths:
        print(f"No supplied PNG files found in {args.input}; no portrait modules changed.")
        return

    # Prepare the complete conversion before writing any modules.
    encoded = [(path, *encode(path)) for path in paths]
    args.output.mkdir(parents=True, exist_ok=True)
    report = []
    for path, source, record in encoded:
        destination = args.output / (path.stem + ".luau")
        destination.write_text(source, encoding="utf-8", newline="\n")
        record["module"] = destination.name
        report.append(record)
        print(f"Encoded {path.name} -> {destination}")
    manifest = args.manifest or args.input / "portrait-manifest.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
