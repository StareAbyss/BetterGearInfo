"""Build a clean installable addon ZIP, without third-party dependencies."""

from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
FILES = ("BetterGearInfo.toc", "BetterGearInfo.lua", "README.md", "LICENSE")


def main():
    toc = (ROOT / FILES[0]).read_text(encoding="utf-8-sig")
    match = re.search(r"^## Version:\s*([0-9]+(?:\.[0-9]+)*)\s*$", toc, re.MULTILINE)
    if not match:
        raise ValueError("Missing or invalid version in BetterGearInfo.toc")
    for filename in FILES:
        if not (ROOT / filename).is_file():
            raise FileNotFoundError(filename)
    output = ROOT / "dist" / f"BetterGearInfo-{match[1]}.zip"
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for filename in FILES:
            archive.write(ROOT / filename, f"BetterGearInfo/{filename}")
    with ZipFile(output) as archive:
        assert archive.testzip() is None
        assert archive.namelist() == [f"BetterGearInfo/{f}" for f in FILES]
    print(output)


if __name__ == "__main__":
    main()
