#!/usr/bin/env python3
"""Export a shop/paywall screenshot to App Store Connect IAP review sizes.

ASC rejects arbitrary phone sizes. Use one of the exact dimensions below.

Requires: Pillow  (`pip install pillow`)

Usage:
  python scripts/export-iap-review-screenshot.py path/to/shop.png
  python scripts/export-iap-review-screenshot.py shop.png --prefix iap_review_lifetime
  python scripts/export-iap-review-screenshot.py shop.png --out-dir assets
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

# Sizes that have worked for U-Things IAP review uploads (Stikkteller).
APPLE_IPHONE_SIZES: tuple[tuple[int, int], ...] = (
    (1242, 2688),
    (1284, 2778),
    (1242, 2208),
    (1320, 2868),
)


def _fit_cover(src: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale to cover target, then center-crop (no letterboxing)."""
    tw, th = size
    sw, sh = src.size
    scale = max(tw / sw, th / sh)
    nw, nh = int(round(sw * scale)), int(round(sh * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    left = max(0, (nw - tw) // 2)
    top = max(0, (nh - th) // 2)
    return resized.crop((left, top, left + tw, top + th))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Source PNG/JPEG screenshot")
    parser.add_argument(
        "--prefix",
        default="iap_review",
        help="Output filename prefix (default: iap_review)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Output directory (default: same as source)",
    )
    args = parser.parse_args()

    src_path: Path = args.source
    if not src_path.is_file():
        raise SystemExit(f"Source not found: {src_path}")

    out_dir: Path = args.out_dir or src_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    src = Image.open(src_path).convert("RGB")
    print(f"source {src.size} ← {src_path}")

    for w, h in APPLE_IPHONE_SIZES:
        out = out_dir / f"{args.prefix}_{w}x{h}.png"
        _fit_cover(src, (w, h)).save(out, format="PNG", optimize=True)
        print(f"wrote  {w}x{h} → {out}")

    print("Upload one size ASC accepts (try 1242x2688 or 1284x2778 first).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
