"""Shared helpers: geo<->pixel, label rasterization, per-pixel features."""
import json, math, os
import cv2
import numpy as np

T = 256
SCALE = 2  # work at half resolution (~0.54 m/px)
CLASSES = ["other", "fairway", "green", "tee", "bunker", "water"]
KIND_TO_CLASS = {"fairway": 1, "green": 2, "tee": 3, "bunker": 4, "water": 5, "lateralWater": 5}
# later entries overwrite earlier ones
DRAW_ORDER = ["fairway", "tee", "green", "water", "lateralWater", "bunker"]


def lonlat_to_px(lon, lat, z):
    n = 2 ** z * T
    return (lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n


def px_to_lonlat(x, y, z):
    n = 2 ** z * T
    lon = x / n * 360 - 180
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    return lon, lat


def load(workdir):
    meta = json.load(open(os.path.join(workdir, "meta.json")))
    img = cv2.imread(os.path.join(workdir, "mosaic.png"))
    mask = cv2.imread(os.path.join(workdir, "mask.png"), cv2.IMREAD_GRAYSCALE)
    h, w = img.shape[0] // SCALE, img.shape[1] // SCALE
    # fine texture from full resolution (greens are much smoother than fairways)
    Lf = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)[..., 0].astype(np.float32) / 255
    fine = np.stack([cv2.resize(_std(Lf, k), (w, h), interpolation=cv2.INTER_AREA) for k in (3, 7)], -1)
    img = cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA)
    meta["fine"] = fine
    mask = cv2.resize(mask, (w, h), interpolation=cv2.INTER_NEAREST)
    meta["mpp_work"] = meta["mpp"] * SCALE
    return meta, img, mask


def to_px(meta, lon, lat):
    x, y = lonlat_to_px(lon, lat, meta["z"])
    return (x - meta["ox"]) / SCALE, (y - meta["oy"]) / SCALE


def to_lonlat(meta, x, y):
    return px_to_lonlat(x * SCALE + meta["ox"], y * SCALE + meta["oy"], meta["z"])


def course_features(course):
    feats = list(course.get("features", []))
    for h in course.get("holes", []):
        feats += h.get("features", [])
    return feats


def rasterize(meta, shape, course):
    lab = np.zeros(shape, np.uint8)
    feats = course_features(course)
    for kind in DRAW_ORDER:
        for f in feats:
            if f["kind"] != kind or len(f["polygon"]) < 3:
                continue
            pts = np.array([to_px(meta, p["lon"], p["lat"]) for p in f["polygon"]], np.float32)
            cv2.fillPoly(lab, [np.round(pts).astype(np.int32)], KIND_TO_CLASS[kind])
    return lab


def _std(x, k):
    m = cv2.blur(x, (k, k))
    return np.sqrt(np.maximum(cv2.blur(x * x, (k, k)) - m * m, 0))


def pixel_features(img, mask):
    """img: BGR uint8, mask: course area -> (H, W, F) float32.
    Base channels are also given normalized by the course's own median/IQR so that
    imagery from different years/seasons/haze looks alike."""
    f = img.astype(np.float32) / 255
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32) / 255
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    b, g, r = f[..., 0], f[..., 1], f[..., 2]
    exg = 2 * g - r - b
    L = lab[..., 0]
    raw = [lab[..., 0], lab[..., 1], lab[..., 2], hsv[..., 1] / 255, exg]
    inside = mask > 0
    chans = []
    for c in raw:
        q1, q2, q3 = np.percentile(c[inside], [25, 50, 75])
        chans.append((c - q2) / max(q3 - q1, 1e-3))
    out = list(raw) + chans
    for s in (2, 6, 15):
        for c in chans:
            out.append(cv2.GaussianBlur(c, (0, 0), s))
    for k in (5, 11, 25):
        out.append(_std(L, k))
        out.append(_std(exg, k))
    gx = cv2.Sobel(L, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(L, cv2.CV_32F, 0, 1, ksize=3)
    gm = np.sqrt(gx * gx + gy * gy)
    for s in (3, 10):
        out.append(cv2.GaussianBlur(gm, (0, 0), s))
    return np.stack(out, -1).astype(np.float32)


def full_features(meta, img, mask):
    fine = meta["fine"]
    extra = [fine[..., 0], fine[..., 1]] + [cv2.GaussianBlur(fine[..., 1], (0, 0), s) for s in (3, 8)]
    return np.concatenate([pixel_features(img, mask), np.stack(extra, -1)], -1)


def context_features(probs):
    """Blurred stage-1 class probabilities at several scales (auto-context)."""
    out = []
    for s in (3, 10, 30):
        for c in range(probs.shape[-1]):
            out.append(cv2.GaussianBlur(probs[..., c], (0, 0), s))
    return np.stack(out, -1).astype(np.float32)


def predict_probs(clf, feats, region):
    probs = np.zeros(feats.shape[:2] + (len(CLASSES),), np.float32)
    ys, xs = np.nonzero(region)
    for s in range(0, len(ys), 400_000):
        sl = slice(s, s + 400_000)
        probs[ys[sl], xs[sl]] = clf.predict_proba(feats[ys[sl], xs[sl]])
    return probs
