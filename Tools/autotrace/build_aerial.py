"""Run the model on every downloaded course and write the app's aerial_tw.json.

usage: build_aerial.py <model.pkl> <courses_tw.json> <workroot> <out aerial_tw.json>

Only fairway / bunker / water are emitted (greens are placed by the user in the app).
A kind is skipped for a course that already has OSM features of that kind.
"""
import json, math, os, pickle, sys
import cv2
import numpy as np
from common import load, to_lonlat, course_features
from predict import classify, components
from shapely.geometry import Polygon

# Douglas-Peucker tolerance in degrees (~1.6 m / 1.1 m / 0.7 m) to keep aerial_tw.json small
SIMPLIFY_DEG = {"fairway": 1.5e-5, "water": 1.0e-5, "bunker": 0.6e-5}


def simplify(kind, pts):
    s = Polygon(pts).simplify(SIMPLIFY_DEG[kind], preserve_topology=True)
    if s.is_empty or s.geom_type != "Polygon":
        return []
    return list(s.exterior.coords)[:-1]

KINDS = ["fairway", "bunker", "water"]
BUNKER_MAX_GAP_M = 60  # bunkers far from any fairway are usually bare soil / construction
ATTRIBUTION = "航照 © 內政部國土測繪中心（政府資料開放授權條款）；自動辨識，僅供參考"


def detect(model, workdir):
    meta, img, mask = load(workdir)
    mpp = meta["mpp_work"]
    pred = classify(model, meta, img, mask)
    polys = {k: components(pred, k, mpp) for k in KINDS}
    fw = np.zeros(mask.shape, np.uint8)
    cv2.fillPoly(fw, polys["fairway"], 1)
    dist = cv2.distanceTransform(1 - fw, cv2.DIST_L2, 5) * mpp
    kept = []
    for p in polys["bunker"]:
        x, y = p.reshape(-1, 2).mean(0)
        if dist[min(int(y), dist.shape[0] - 1), min(int(x), dist.shape[1] - 1)] <= BUNKER_MAX_GAP_M:
            kept.append(p)
    polys["bunker"] = kept
    out = []
    for k in KINDS:
        for p in polys[k]:
            pts = [to_lonlat(meta, float(x), float(y)) for x, y in p.reshape(-1, 2)]
            pts = simplify(k, pts) if len(pts) >= 3 else []
            if len(pts) >= 3:
                out.append({"kind": k, "polygon": [{"lat": round(la, 6), "lon": round(lo, 6)} for lo, la in pts]})
    return out


def main():
    model = pickle.load(open(sys.argv[1], "rb"))
    courses = json.load(open(sys.argv[2]))
    root, out_path = sys.argv[3], sys.argv[4]
    result, summary = {}, []
    for c in courses:
        if "練習" in c["name"]:
            continue
        wd = os.path.join(root, c["id"].split("-")[-1])
        if not os.path.exists(os.path.join(wd, "mosaic.png")):
            summary.append((c["name"], "no imagery")); continue
        have = {f["kind"] for f in course_features(c)}
        feats = [f for f in detect(model, wd) if f["kind"] not in have]
        if feats:
            result[c["id"]] = feats
        counts = {k: sum(f["kind"] == k for f in feats) for k in KINDS}
        summary.append((c["name"], counts))
        print(c["name"], counts, flush=True)
    json.dump({"attribution": ATTRIBUTION, "courses": result}, open(out_path, "w"),
              ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    print(f"courses with aerial features: {len(result)}; total features: {sum(map(len, result.values()))}")
    for name, s in summary:
        if s == "no imagery": print("  no imagery:", name)


if __name__ == "__main__":
    main()
