"""Train a two-stage (auto-context) per-pixel classifier from OSM-mapped courses.

usage: train.py <courses_tw.json> <workroot> <model.pkl> <id> [<id> ...]
ids are numeric OSM ids whose mosaics live in <workroot>/<id>/
Stage 1 sees pixel colour/texture; stage 2 additionally sees blurred stage-1
probabilities around each pixel (out-of-fold, so it learns from realistic mistakes).
"""
import json, pickle, sys
import cv2
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier
from common import (load, rasterize, full_features, context_features, predict_probs,
                    course_features, CLASSES)

PER_CLASS = 6000
rng = np.random.default_rng(0)


def new_clf():
    return HistGradientBoostingClassifier(max_iter=300, learning_rate=0.1, max_leaf_nodes=63,
                                          class_weight="balanced", random_state=0)


def region_of(mask):
    return cv2.dilate(mask, np.ones((15, 15), np.uint8)) > 0


def sample_coords(course, meta, mask):
    lab = rasterize(meta, mask.shape, course)
    has_fw = any(f["kind"] == "fairway" for f in course_features(course))
    coords, y = [], []
    for c in range(len(CLASSES)):
        m = (lab == c).astype(np.uint8)
        if c == 0:
            if not has_fw:  # unlabeled fairways would pollute "other"
                continue
            m = cv2.erode(m & (mask > 0), np.ones((9, 9), np.uint8))
        else:
            m = cv2.erode(m, np.ones((5, 5), np.uint8))  # OSM/imagery misalignment at edges
        ys, xs = np.nonzero(m)
        if len(ys) == 0:
            continue
        n = PER_CLASS * (3 if c == 0 else 1)
        idx = rng.choice(len(ys), min(n, len(ys)), replace=False)
        coords.append(np.stack([ys[idx], xs[idx]], 1)); y.append(np.full(len(idx), c))
    return np.concatenate(coords), np.concatenate(y)


def main():
    courses = {c["id"].split("-")[-1]: c for c in json.load(open(sys.argv[1]))}
    root, out, ids = sys.argv[2], sys.argv[3], sys.argv[4:]
    data = {}
    for i in ids:  # pass 1: stage-1 samples
        meta, img, mask = load(f"{root}/{i}")
        coords, y = sample_coords(courses[i], meta, mask)
        feats = full_features(meta, img, mask)
        data[i] = (coords, y, feats[coords[:, 0], coords[:, 1]])
        print(i, courses[i]["name"], np.bincount(y, minlength=len(CLASSES)), flush=True)
    folds = [ids[0::2], ids[1::2]]
    fold_models = []
    for k in (0, 1):
        clf = new_clf()
        clf.fit(np.concatenate([data[i][2] for i in folds[1 - k]]),
                np.concatenate([data[i][1] for i in folds[1 - k]]))
        fold_models.append(clf)  # fold_models[k] predicts courses in folds[k]
    X2, Y = [], []
    for k in (0, 1):  # pass 2: out-of-fold context features
        for i in folds[k]:
            meta, img, mask = load(f"{root}/{i}")
            feats = full_features(meta, img, mask)
            ctx = context_features(predict_probs(fold_models[k], feats, region_of(mask)))
            coords, y, x1 = data[i]
            X2.append(np.concatenate([x1, ctx[coords[:, 0], coords[:, 1]]], 1)); Y.append(y)
            print("ctx", i, flush=True)
    stage1 = new_clf().fit(np.concatenate([d[2] for d in data.values()]),
                           np.concatenate([d[1] for d in data.values()]))
    stage2 = new_clf().fit(np.concatenate(X2), np.concatenate(Y))
    pickle.dump({"stage1": stage1, "stage2": stage2}, open(out, "wb"))
    print("trained on", sum(len(d[1]) for d in data.values()), "pixels")


if __name__ == "__main__":
    main()
