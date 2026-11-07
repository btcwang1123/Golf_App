"""Run the classifier on one course mosaic and vectorize into course features.

usage: predict.py <model.pkl> <workdir> <out.json> [<courses_tw.json> <osm id>]   (last two: evaluate vs OSM)
Writes <out.json> ({"features": [...]}) and <workdir>/overlay.jpg
"""
import json, pickle, sys
import cv2
import numpy as np
from common import load, rasterize, full_features, context_features, predict_probs, to_lonlat, CLASSES

# class -> (min m², max m², open kernel m, close kernel m, min solidity)
POST = {
    "fairway": (800, 1e9, 3.0, 4.0, 0.0),
    "green": (150, 2500, 2.0, 1.5, 0.80),
    "tee": (30, 1500, 1.5, 1.0, 0.70),
    "bunker": (10, 1500, 0.8, 0.8, 0.50),
    "water": (80, 1e9, 2.0, 2.0, 0.40),
}
COLORS = {"fairway": (90, 200, 110), "green": (130, 255, 160), "tee": (60, 220, 230),
          "bunker": (170, 230, 250), "water": (230, 140, 40)}
SIMPLIFY_M = 0.7


def kernel(m, mpp):
    k = max(1, int(round(m / mpp)))
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))


def classify(model, meta, img, mask):
    feats = full_features(meta, img, mask)
    inside = cv2.dilate(mask, np.ones((15, 15), np.uint8)) > 0
    ctx = context_features(predict_probs(model["stage1"], feats, inside))
    probs = predict_probs(model["stage2"], np.concatenate([feats, ctx], -1), inside)
    for c in range(len(CLASSES)):
        probs[..., c] = cv2.GaussianBlur(probs[..., c], (0, 0), 1.2)
    pred = probs.argmax(-1).astype(np.uint8)
    pred[~inside] = 0
    return pred


def components(pred, cls, mpp):
    lo, hi, op, cl, sol = POST[cls]
    m = (pred == CLASSES.index(cls)).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, kernel(op, mpp))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, kernel(cl, mpp))
    cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    keep = []
    for c in cnts:
        a = cv2.contourArea(c) * mpp * mpp
        if not lo <= a <= hi:
            continue
        hull = cv2.contourArea(cv2.convexHull(c))
        if hull <= 0 or cv2.contourArea(c) / hull < sol:
            continue
        keep.append(cv2.approxPolyDP(c, SIMPLIFY_M / mpp, True))
    return keep


def evaluate(pred_masks, lab, mask, mpp):
    print(f"{'class':8} {'pixIoU':>6} {'GT':>4} {'found':>5} {'pred':>4} {'correct':>7}")
    for cls, polys in pred_masks.items():
        ci = CLASSES.index(cls)
        pm = np.zeros(lab.shape, np.uint8)
        cv2.fillPoly(pm, polys, 1)
        gt = (lab == ci).astype(np.uint8)
        if gt.sum() == 0:
            print(f"{cls:8}   (no OSM labels)  pred={len(polys)}")
            continue
        inter = (pm & gt & (mask > 0)).sum(); union = ((pm | gt) & (mask > 0)).sum()
        n, gl = cv2.connectedComponents(gt)
        # GT object counted as found if >=30% of it is covered; pred object correct if >=30% inside GT
        found = sum((pm[gl == i].mean() >= 0.3) for i in range(1, n) if (gl == i).sum() * mpp * mpp >= 8)
        ngt = sum(1 for i in range(1, n) if (gl == i).sum() * mpp * mpp >= 8)
        correct = 0
        for p in polys:
            one = np.zeros(lab.shape, np.uint8); cv2.fillPoly(one, [p], 1)
            if gt[one > 0].mean() >= 0.3: correct += 1
        print(f"{cls:8} {inter / max(union, 1):6.2f} {ngt:4d} {found:5d} {len(polys):4d} {correct:7d}")


def main():
    clf = pickle.load(open(sys.argv[1], "rb"))
    workdir, out = sys.argv[2], sys.argv[3]
    meta, img, mask = load(workdir)
    mpp = meta["mpp_work"]
    pred = classify(clf, meta, img, mask)
    result = {cls: components(pred, cls, mpp) for cls in POST}
    feats = []
    overlay = img.copy()
    for cls, polys in result.items():
        for p in polys:
            pts = p.reshape(-1, 2)
            feats.append({"kind": cls, "polygon": [
                {"lat": round(lat, 7), "lon": round(lon, 7)} for lon, lat in (to_lonlat(meta, x, y) for x, y in pts)]})
        cv2.polylines(overlay, polys, True, COLORS[cls], 2)
    json.dump({"name": meta["name"], "features": feats}, open(out, "w"), ensure_ascii=False)
    cv2.imwrite(f"{workdir}/overlay.jpg", overlay, [cv2.IMWRITE_JPEG_QUALITY, 85])
    print(meta["name"], {k: len(v) for k, v in result.items()})
    if len(sys.argv) > 5:
        courses = {c["id"].split("-")[-1]: c for c in json.load(open(sys.argv[4]))}
        evaluate(result, rasterize(meta, mask.shape, courses[sys.argv[5]]), mask, mpp)


if __name__ == "__main__":
    main()
