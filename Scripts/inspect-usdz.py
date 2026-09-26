#!/usr/bin/env python3
"""Read-only USDZ geometry/texture audit. Requires Python 3 and Apple's usdcat.

Usage: python3 Scripts/inspect-usdz.py model.usdz [reference.usdz]
Does not decode texture pixels, modify assets, or infer capture quality from counts.
"""
import argparse
import json
import re
import shutil
import struct
import subprocess
import zipfile
from pathlib import Path


def inspect(path):
    path = Path(path).resolve(strict=True)
    report = {"file": path.name, "bytes": path.stat().st_size, "textures": []}
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            if not entry.filename.lower().endswith(".png"):
                continue
            with archive.open(entry) as stream:
                header = stream.read(24)
            if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
                raise ValueError(f"Invalid PNG: {entry.filename}")
            width, height = struct.unpack(">II", header[16:24])
            report["textures"].append({"name": entry.filename, "width": width, "height": height,
                                       "colorMapByObjectCaptureName": bool(re.search(r"_tex\d+\.png$", entry.filename))})
    report["colorPixels"] = sum(t["width"] * t["height"] for t in report["textures"] if t["colorMapByObjectCaptureName"])
    usdcat = shutil.which("usdcat")
    if not usdcat:
        report["geometryUnavailable"] = "Install Apple USD tools (usdcat) to measure mesh geometry."
        return report
    faces = triangles = vertices = 0
    # Stream the USDA rather than retaining the whole expanded mesh in memory.
    with subprocess.Popen([usdcat, str(path)], stdout=subprocess.PIPE, text=True) as process:
        for line in process.stdout:
            if "faceVertexCounts = [" in line:
                values = line.split("[", 2)[-1].rsplit("]", 1)[0]
                faces += values.count(",") + 1 if values.strip() else 0
                triangles += len(re.findall(r"\b3\b", values))
            elif "point3f[] points = [" in line:
                vertices += line.count("(")
        if process.wait() != 0:
            raise RuntimeError("usdcat could not inspect the mesh")
    report.update(faces=faces, triangles=triangles, vertices=vertices)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model")
    parser.add_argument("reference", nargs="?")
    args = parser.parse_args()
    result = {"model": inspect(args.model)}
    if args.reference:
        result["reference"] = inspect(args.reference)
        result["ratios"] = {key: result["model"][key] / result["reference"][key]
                            for key in ("triangles", "colorPixels")
                            if key in result["model"] and result["reference"].get(key)}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
