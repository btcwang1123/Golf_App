"""Download an NLSC orthophoto mosaic covering one OSM golf course boundary.

usage: fetch.py <overpass-cache.json> <osm-way-or-relation-id> <outdir> [zoom]
Writes <outdir>/mosaic.png, <outdir>/mask.png (course boundary), <outdir>/meta.json
"""
import json, math, os, sys, time, urllib.request
from PIL import Image, ImageDraw

URL = "https://wmts.nlsc.gov.tw/wmts/PHOTO2/default/GoogleMapsCompatible/{z}/{y}/{x}"
T = 256


def lonlat_to_px(lon, lat, z):
    n = 2 ** z * T
    x = (lon + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y


def stitch(segs):
    """Join open way segments sharing endpoints into closed rings."""
    segs = [list(s) for s in segs if s]
    rings = []
    while segs:
        ring = segs.pop(0)
        changed = True
        while ring[0] != ring[-1] and changed:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == ring[-1]: ring += s[1:]
                elif s[-1] == ring[-1]: ring += s[-2::-1]
                elif s[-1] == ring[0]: ring = s[:-1] + ring
                elif s[0] == ring[0]: ring = s[:0:-1] + ring
                else: continue
                segs.pop(i); changed = True
                break
        rings.append(ring)
    return rings


def boundary(cache, oid):
    els = json.load(open(cache))["elements"]
    for e in els:
        if e.get("id") == oid and e["type"] in ("way", "relation"):
            if e["type"] == "way":
                return [[(p["lon"], p["lat"]) for p in e["geometry"]]], e["tags"].get("name")
            segs = [[(p["lon"], p["lat"]) for p in m["geometry"]]
                    for m in e["members"] if m.get("role") == "outer" and "geometry" in m]
            return stitch(segs), e["tags"].get("name")
    raise SystemExit(f"id {oid} not found")


def main():
    cache, oid, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    z = int(sys.argv[4]) if len(sys.argv) > 4 else 19
    os.makedirs(os.path.join(out, "tiles"), exist_ok=True)
    rings, name = boundary(cache, oid)
    pts = [p for r in rings for p in r]
    xs, ys = zip(*(lonlat_to_px(lon, lat, z) for lon, lat in pts))
    pad = 64
    x0, y0 = int(min(xs)) - pad, int(min(ys)) - pad
    x1, y1 = int(max(xs)) + pad, int(max(ys)) + pad
    tx0, ty0, tx1, ty1 = x0 // T, y0 // T, x1 // T, y1 // T
    W, H = (tx1 - tx0 + 1) * T, (ty1 - ty0 + 1) * T
    if (tx1 - tx0 + 1) * (ty1 - ty0 + 1) > 2500:
        raise SystemExit(f"{name}: boundary too large ({W}x{H}px), skipped")
    img = Image.new("RGB", (W, H))
    n = 0
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            fp = os.path.join(out, "tiles", f"{z}_{ty}_{tx}.jpg")
            if not os.path.exists(fp):
                req = urllib.request.Request(URL.format(z=z, y=ty, x=tx),
                                             headers={"User-Agent": "golf-app-autotrace/0.1"})
                for attempt in range(4):
                    try:
                        with urllib.request.urlopen(req, timeout=30) as r:
                            data = r.read()
                        break
                    except Exception:
                        if attempt == 3: raise
                        time.sleep(2 * (attempt + 1))
                open(fp + ".part", "wb").write(data)
                os.replace(fp + ".part", fp)
                n += 1
                time.sleep(0.05)
            try:
                img.paste(Image.open(fp).convert("RGB"), ((tx - tx0) * T, (ty - ty0) * T))
            except Exception:  # missing/blank tile (e.g. outside imagery coverage): leave black
                os.remove(fp)
    ox, oy = tx0 * T, ty0 * T
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    for r in rings:
        d.polygon([(lonlat_to_px(lon, lat, z)[0] - ox, lonlat_to_px(lon, lat, z)[1] - oy) for lon, lat in r], fill=255)
    img.save(os.path.join(out, "mosaic.png"))
    mask.save(os.path.join(out, "mask.png"))
    lat_c = sum(p[1] for p in pts) / len(pts)
    mpp = 156543.03392 * math.cos(math.radians(lat_c)) / 2 ** z
    json.dump({"name": name, "id": oid, "z": z, "ox": ox, "oy": oy, "w": W, "h": H, "mpp": mpp},
              open(os.path.join(out, "meta.json"), "w"), ensure_ascii=False)
    print(f"{name}: {W}x{H}px, {mpp:.2f} m/px, downloaded {n} tiles")


if __name__ == "__main__":
    main()
