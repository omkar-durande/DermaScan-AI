# Running locally — no Google Colab drive mount needed
import os, random, math, json
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from PIL import Image
from tqdm import tqdm

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from torchvision import models, transforms
from sklearn.model_selection import train_test_split
from sklearn.metrics import (classification_report, balanced_accuracy_score,
                              confusion_matrix, accuracy_score)
import torch

# Dynamically check if a GPU is available
use_cuda = torch.cuda.is_available()


# ─────────────────────────────────────────────
# 1. CONFIGURATION
# ─────────────────────────────────────────────

# Base directory: folder containing this script
_BASE_DIR = os.path.dirname(os.path.abspath(__file__))

CONFIG = {
    # ── Dataset paths ──────────────────────────────────────────────────
    "dataset_dir"   : os.path.join(_BASE_DIR, "dataset"),
    "csv_path"      : os.path.join(_BASE_DIR, "dataset", "metadata.csv"),
    "image_dirs"    : [
        "imgs_part_1/imgs_part_1/",
        "imgs_part_2/imgs_part_2/",
        "imgs_part_3/imgs_part_3/",
    ],

    # ── OOD (non-skin) images ──────────────────────────────────────────
    # If this folder exists and has >=100 images, those are used directly.
    # Otherwise the script auto-downloads CIFAR-100 (no Kaggle login needed).
    "non_skin_dir"          : os.path.join(_BASE_DIR, "non_skin_images"),
    "auto_download_non_skin": False,   # disabled: CIFAR-100 server too slow locally
    "non_skin_cache_dir"    : os.path.join(_BASE_DIR, "non_skin_auto"),
    "non_skin_auto_count"   : 3000,

    # ── Output paths ───────────────────────────────────────────────────
    "output_dir"    : os.path.join(_BASE_DIR, "skin_model_outputs"),
    "model_out"     : os.path.join(_BASE_DIR, "skin_model_outputs", "skin_model_best.pth"),
    "ood_model_out" : os.path.join(_BASE_DIR, "skin_model_outputs", "ood_classifier.pth"),

    # ── Model / training ───────────────────────────────────────────────
    "num_classes"        : 6,
    "img_size"           : 300,   # EfficientNet-B3 native size
    "batch_size"         : 8,   # reduced from 24 to fit 3.68 GB GPU
    "epochs_warmup"      : 6,     # frozen backbone
    "epochs_finetune"    : 34,    # full fine-tune
    "lr_warmup"          : 1e-3,
    "lr_finetune"        : 1e-4,
    "min_lr"             : 1e-6,
    "weight_decay"       : 1e-4,
    "val_size"           : 0.15,
    "test_size"          : 0.15,
    "seed"               : 42,
    "device"             : "cuda" if torch.cuda.is_available() else "cpu",
    "early_stop_patience": 8,

    # ── OOD rejection thresholds ───────────────────────────────────────
    "conf_threshold"     : 0.55,
    "entropy_threshold"  : 1.3,
}

CLASS_NAMES = ["NEV", "BCC", "ACK", "SEK", "SCC", "MEL"]
LABEL_MAP   = {name: i for i, name in enumerate(CLASS_NAMES)}

CLASS_INFO = {
    # 6 original classes
    "NEV": {"full_name": "Melanocytic Nevus",              "severity": "low"},
    "BCC": {"full_name": "Basal Cell Carcinoma",            "severity": "high"},
    "ACK": {"full_name": "Actinic Keratosis",               "severity": "moderate"},
    "SEK": {"full_name": "Seborrheic Keratosis",            "severity": "low"},
    "SCC": {"full_name": "Squamous Cell Carcinoma",         "severity": "high"},
    "MEL": {"full_name": "Melanoma",                        "severity": "critical"},
    
    # 10 classes from new model (mapped by display name)
    "Melanoma": {"full_name": "Melanoma", "severity": "critical"},
    "Melanocytic Nevi (Moles)": {"full_name": "Melanocytic Nevi (Moles)", "severity": "low"},
    "Basal Cell Carcinoma": {"full_name": "Basal Cell Carcinoma", "severity": "high"},
    "Actinic Keratosis": {"full_name": "Actinic Keratosis", "severity": "moderate"},
    "Benign Keratosis": {"full_name": "Benign Keratosis", "severity": "low"},
    "Dermatofibroma": {"full_name": "Dermatofibroma", "severity": "low"},
    "Vascular Lesions": {"full_name": "Vascular Lesions", "severity": "low"},
    "Eczema / Dermatitis": {"full_name": "Eczema / Dermatitis", "severity": "moderate"},
    "Psoriasis": {"full_name": "Psoriasis", "severity": "moderate"},
    "Tinea / Fungal Infection": {"full_name": "Tinea / Fungal Infection", "severity": "low"}
}


def set_seed(seed):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


# ─────────────────────────────────────────────
# 2. IMAGE MAP
# ─────────────────────────────────────────────

def build_image_map(dataset_dir, image_dirs):
    image_map = {}
    for subfolder in image_dirs:
        folder_path = os.path.join(dataset_dir, subfolder)
        if not os.path.exists(folder_path):
            print(f"  Warning: subfolder not found -> {folder_path}")
            continue
        for fname in os.listdir(folder_path):
            if fname.lower().endswith((".png", ".jpg", ".jpeg")):
                key = os.path.splitext(fname)[0]
                image_map[key] = os.path.join(folder_path, fname)
    print(f"  Found {len(image_map)} images")
    return image_map


# ─────────────────────────────────────────────
# 3. DATASETS
# ─────────────────────────────────────────────

class SkinDiseaseDataset(Dataset):
    """Returns (image_tensor, label_int, image_path) per sample."""
    def __init__(self, df, image_map, transform=None):
        df = df.copy()
        df["_key"] = df["img_id"].str.replace(
            r"\.(png|jpg|jpeg)$", "", case=False, regex=True)
        self.df        = df[df["_key"].isin(image_map)].reset_index(drop=True)
        self.image_map = image_map
        self.transform = transform
        skipped = len(df) - len(self.df)
        if skipped:
            print(f"  Skipped {skipped} rows — no matching image file")

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row   = self.df.iloc[idx]
        path  = self.image_map[row["_key"]]
        image = Image.open(path).convert("RGB")
        label = LABEL_MAP[row["diagnostic"]]
        if self.transform:
            image = self.transform(image)
        return image, label, path


class BinaryOODDataset(Dataset):
    """Label 1 = skin lesion, Label 0 = non-skin."""
    def __init__(self, skin_paths, non_skin_paths, transform=None):
        self.paths     = skin_paths + non_skin_paths
        self.labels    = [1] * len(skin_paths) + [0] * len(non_skin_paths)
        self.transform = transform

    def __len__(self):
        return len(self.paths)

    def __getitem__(self, idx):
        image = Image.open(self.paths[idx]).convert("RGB")
        if self.transform:
            image = self.transform(image)
        return image, self.labels[idx]


# ─────────────────────────────────────────────
# 4. TRANSFORMS
# ─────────────────────────────────────────────

def get_transforms(img_size):
    mean = [0.485, 0.456, 0.406]
    std  = [0.229, 0.224, 0.225]

    train_tf = transforms.Compose([
        transforms.Resize((img_size + 20, img_size + 20)),
        transforms.RandomCrop(img_size),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomRotation(20),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.15),
        transforms.ToTensor(),
        transforms.Normalize(mean, std),
        transforms.RandomErasing(p=0.15, scale=(0.02, 0.1)),
    ])
    val_tf = transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean, std),
    ])
    return train_tf, val_tf


def get_tta_transforms(img_size):
    """4 TTA views: original, horizontal flip, +10° rotation, -10° rotation."""
    mean = [0.485, 0.456, 0.406]
    std  = [0.229, 0.224, 0.225]
    views = []
    for angle, flip in [(0, False), (0, True), (10, False), (-10, False)]:
        ops = [transforms.Resize((img_size, img_size))]
        if angle:
            ops.append(transforms.RandomRotation((angle, angle)))
        if flip:
            ops.append(transforms.RandomHorizontalFlip(p=1.0))
        ops += [transforms.ToTensor(), transforms.Normalize(mean, std)]
        views.append(transforms.Compose(ops))
    return views


# ─────────────────────────────────────────────
# 5. LOSS
# ─────────────────────────────────────────────

class FocalLoss(nn.Module):
    """Focal loss with per-class weights and label smoothing."""
    def __init__(self, class_weights=None, gamma=2.0,
                 label_smoothing=0.05, num_classes=6):
        super().__init__()
        self.gamma           = gamma
        self.label_smoothing = label_smoothing
        self.num_classes     = num_classes
        self.register_buffer(
            "class_weights",
            class_weights if class_weights is not None
            else torch.ones(num_classes)
        )

    def forward(self, logits, targets):
        with torch.no_grad():
            smooth = torch.full_like(
                logits, self.label_smoothing / (self.num_classes - 1))
            smooth.scatter_(1, targets.unsqueeze(1), 1.0 - self.label_smoothing)

        log_p = F.log_softmax(logits, dim=1)
        focal = (1 - log_p.exp()) ** self.gamma
        loss  = -(focal * smooth * log_p).sum(dim=1)
        return (loss * self.class_weights[targets]).mean()


def compute_class_weights(df, device):
    """Inverse-frequency weights; normalised so they average to 1."""
    counts  = df["diagnostic"].value_counts()
    weights = [1.0 / counts.get(cls, 1) for cls in CLASS_NAMES]
    weights = torch.tensor(weights, dtype=torch.float32)
    weights = weights / weights.sum() * len(CLASS_NAMES)
    return weights.to(device)


# ─────────────────────────────────────────────
# 6. MODELS
# ─────────────────────────────────────────────

def build_disease_model(num_classes, device, pretrained=True):
    weights = models.EfficientNet_B3_Weights.DEFAULT if pretrained else None
    model   = models.efficientnet_b3(weights=weights)

    # Freeze backbone initially; unfrozen at Stage 2
    for p in model.features.parameters():
        p.requires_grad = False

    in_f = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.4),
        nn.Linear(in_f, 512),
        nn.SiLU(),
        nn.BatchNorm1d(512),
        nn.Dropout(p=0.3),
        nn.Linear(512, num_classes),
    )
    return model.to(device)


def build_ood_model(device):
    """Lightweight binary classifier: skin (1) vs non-skin (0)."""
    model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
    in_f  = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(in_f, 1),
    )
    return model.to(device)


def unfreeze_backbone(model):
    for p in model.features.parameters():
        p.requires_grad = True
    print("  Backbone unfrozen — fine-tuning all layers")


# ─────────────────────────────────────────────
# 7. LR SCHEDULE  (cosine with linear warmup)
# ─────────────────────────────────────────────

def get_lr(epoch, total_epochs, base_lr, min_lr, warmup_epochs=2):
    if epoch < warmup_epochs:
        return base_lr * (epoch + 1) / warmup_epochs
    progress = (epoch - warmup_epochs) / max(total_epochs - warmup_epochs, 1)
    return min_lr + 0.5 * (base_lr - min_lr) * (1 + math.cos(math.pi * progress))


# ─────────────────────────────────────────────
# 8. WEIGHTED SAMPLER
# ─────────────────────────────────────────────

def make_weighted_sampler(df):
    labels      = [LABEL_MAP[d] for d in df["diagnostic"]]
    counts      = np.bincount(labels)
    w_per_class = 1.0 / counts
    sample_w    = [w_per_class[l] for l in labels]
    return WeightedRandomSampler(
        torch.DoubleTensor(sample_w), len(sample_w), replacement=True)


# ─────────────────────────────────────────────
# 9. TRAIN / VALIDATE ONE EPOCH
# ─────────────────────────────────────────────

def train_one_epoch(model, loader, criterion, optimizer, device):
    model.train()
    total_loss, correct, total = 0.0, 0, 0
    for inputs, labels, _ in tqdm(loader, desc="  Train", leave=False):
        inputs, labels = inputs.to(device), labels.to(device)
        outputs = model(inputs)
        loss    = criterion(outputs, labels)

        optimizer.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0);
        optimizer.step()

        total_loss += loss.item() * inputs.size(0)
        correct    += (outputs.argmax(1) == labels).sum().item()
        total      += labels.size(0)
    return total_loss / total, correct / total


def validate(model, loader, criterion, device, collect_paths=False):
    model.eval()
    total_loss, correct, total = 0.0, 0, 0
    all_preds, all_labels, all_probs, all_paths = [], [], [], []

    with torch.no_grad():
        for inputs, labels, paths in tqdm(loader, desc="  Val  ", leave=False):
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            probs   = torch.softmax(outputs, dim=1)
            loss    = criterion(outputs, labels)

            total_loss += loss.item() * inputs.size(0)
            correct    += (outputs.argmax(1) == labels).sum().item()
            total      += labels.size(0)
            all_preds.extend(outputs.argmax(1).cpu().numpy())
            all_labels.extend(labels.cpu().numpy())
            all_probs.extend(probs.cpu().numpy())
            if collect_paths:
                all_paths.extend(paths)

    # cast to plain Python float to avoid numpy scalar in checkpoint dicts
    bal_acc = float(balanced_accuracy_score(all_labels, all_preds))
    result  = {
        "loss": total_loss / total,
        "acc" : correct / total,
        "bal_acc": bal_acc,
        "preds"  : all_preds,
        "labels" : all_labels,
        "probs"  : all_probs,
    }
    if collect_paths:
        result["paths"] = all_paths
    return result


# ─────────────────────────────────────────────
# 10. OOD CLASSIFIER TRAINING
# ─────────────────────────────────────────────

def download_and_extract_non_skin_images(cache_dir, target_count=3000):
    """
    Downloads CIFAR-100 via torchvision (no Kaggle login required) and
    saves `target_count` images to `cache_dir` as PNG files.
    CIFAR-100 contains animals, vehicles, objects, scenes — nothing
    that looks like a skin lesion, making it ideal as a negative class.
    """
    from torchvision.datasets import CIFAR100

    ensure_dir(cache_dir)
    existing = [f for f in os.listdir(cache_dir) if f.lower().endswith(".png")]
    if len(existing) >= target_count:
        print(f"  Using {len(existing)} cached non-skin images from {cache_dir}")
        return [os.path.join(cache_dir, f) for f in existing]

    print("  Downloading CIFAR-100 as non-skin negative examples...")
    ds = CIFAR100(
        root=os.path.join(cache_dir, "_cifar100_raw"),
        train=True, download=True
    )

    n       = min(target_count, len(ds))
    indices = random.sample(range(len(ds)), n)
    paths   = []
    for i, idx in enumerate(indices):
        img, _ = ds[idx]  # PIL Image; label unused
        out_path = os.path.join(cache_dir, f"nonskin_{i:05d}.png")
        if not os.path.exists(out_path):
            img.save(out_path)
        paths.append(out_path)

    print(f"  Saved {len(paths)} non-skin images to {cache_dir}")
    return paths


def collect_non_skin_paths(non_skin_dir, cfg=None):
    """
    Returns a list of non-skin image paths.
    Priority:
      1. Images in non_skin_dir (if >=100 found)
      2. Auto-downloaded CIFAR-100 (if auto_download_non_skin=True in cfg)
      3. Empty list → OOD classifier skipped, threshold-only mode used
    """
    paths = []
    if os.path.exists(non_skin_dir):
        for fname in os.listdir(non_skin_dir):
            if fname.lower().endswith((".png", ".jpg", ".jpeg")):
                paths.append(os.path.join(non_skin_dir, fname))

    if len(paths) >= 100:
        print(f"  Found {len(paths)} non-skin images in {non_skin_dir}")
        return paths

    print(f"  Only {len(paths)} images in non_skin_dir (need >=100).")

    if cfg is not None and cfg.get("auto_download_non_skin", False):
        try:
            downloaded = download_and_extract_non_skin_images(
                cfg.get("non_skin_cache_dir", os.path.join(_BASE_DIR, "non_skin_auto")),
                cfg.get("non_skin_auto_count", 3000),
            )
            paths.extend(downloaded)
            print(f"  Total non-skin images available: {len(paths)}")
        except Exception as e:
            print(f"  Auto-download failed: {e}")
            print("  Falling back to threshold-only OOD mode.")

    return paths


def train_ood_classifier(cfg, image_map):
    print("\n-- Training OOD binary classifier --")
    device = cfg["device"]

    skin_paths     = list(image_map.values())
    non_skin_paths = collect_non_skin_paths(cfg["non_skin_dir"], cfg=cfg)

    if len(non_skin_paths) < 100:
        print("  Skipping OOD binary training — threshold-only mode active.")
        return None

    n = min(len(skin_paths), len(non_skin_paths), 3000)
    random.shuffle(skin_paths)
    random.shuffle(non_skin_paths)
    skin_paths     = skin_paths[:n]
    non_skin_paths = non_skin_paths[:n]

    split    = int(n * 0.85)
    train_tf, val_tf = get_transforms(224)  # B0 uses 224

    train_ds = BinaryOODDataset(skin_paths[:split],  non_skin_paths[:split],  train_tf)
    val_ds   = BinaryOODDataset(skin_paths[split:],  non_skin_paths[split:],  val_tf)

    train_loader = DataLoader(train_ds, batch_size=32, shuffle=True,
                              num_workers=2, pin_memory=True)
    val_loader   = DataLoader(val_ds,   batch_size=32, shuffle=False,
                              num_workers=2, pin_memory=True)

    model     = build_ood_model(device)
    criterion = nn.BCEWithLogitsLoss()
    optimizer = optim.AdamW(model.parameters(), lr=1e-4, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=12)

    best_acc = 0.0
    for epoch in range(1, 13):
        model.train()
        for inputs, labels in train_loader:
            inputs = inputs.to(device)
            labels = labels.float().unsqueeze(1).to(device)
            optimizer.zero_grad()
            criterion(model(inputs), labels).backward()
            optimizer.step()
        scheduler.step()

        model.eval()
        correct, total = 0, 0
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs, labels = inputs.to(device), labels.to(device)
                preds = (torch.sigmoid(model(inputs)).squeeze(1) > 0.5).long()
                correct += (preds == labels).sum().item()
                total   += labels.size(0)
        acc = correct / total
        print(f"  OOD Epoch {epoch:2d} | val acc {acc:.2%}")
        if acc > best_acc:
            best_acc = acc
            torch.save(model.state_dict(), cfg["ood_model_out"])

    print(f"  OOD classifier saved  (best val acc {best_acc:.2%})")
    return cfg["ood_model_out"]


# ─────────────────────────────────────────────
# 11. REPORTING / VISUALISATION
# ─────────────────────────────────────────────

def _add_unfreeze_line(ax, warmup_epochs):
    """Draw a dashed vertical line at the warmup/finetune boundary."""
    if warmup_epochs and warmup_epochs > 0:
        ax.axvline(x=warmup_epochs - 0.5, color="gray", linestyle="--",
                   alpha=0.6, label="Unfreeze backbone")


def plot_accuracy_curve(history, out_dir):
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(history["train_acc"], label="Train Accuracy", linewidth=2)
    ax.plot(history["val_acc"],   label="Val Accuracy",   linewidth=2)
    _add_unfreeze_line(ax, history.get("warmup_epochs", 0))
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Accuracy")
    ax.set_title("Training & Validation Accuracy")
    ax.legend()
    ax.grid(alpha=0.3)
    plt.tight_layout()
    path = os.path.join(out_dir, "accuracy_curve.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"  Saved {path}")


def plot_loss_curve(history, out_dir):
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(history["train_loss"], label="Train Loss", linewidth=2)
    ax.plot(history["val_loss"],   label="Val Loss",   linewidth=2)
    _add_unfreeze_line(ax, history.get("warmup_epochs", 0))
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Loss")
    ax.set_title("Training & Validation Loss")
    ax.legend()
    ax.grid(alpha=0.3)
    plt.tight_layout()
    path = os.path.join(out_dir, "loss_curve.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"  Saved {path}")


def plot_confusion_matrix(labels, preds, class_names, out_dir):
    cm      = confusion_matrix(labels, preds)
    cm_norm = cm.astype("float") / cm.sum(axis=1, keepdims=True)

    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
                xticklabels=class_names, yticklabels=class_names, ax=axes[0])
    axes[0].set_title("Confusion Matrix (Counts)")
    axes[0].set_xlabel("Predicted")
    axes[0].set_ylabel("True")

    sns.heatmap(cm_norm, annot=True, fmt=".2f", cmap="Blues",
                xticklabels=class_names, yticklabels=class_names, ax=axes[1])
    axes[1].set_title("Confusion Matrix (Normalized)")
    axes[1].set_xlabel("Predicted")
    axes[1].set_ylabel("True")

    plt.tight_layout()
    path = os.path.join(out_dir, "confusion_matrix.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"  Saved {path}")
    return cm


def save_classification_report(labels, preds, class_names, out_dir):
    report_str  = classification_report(labels, preds,
                                         target_names=class_names, zero_division=0)
    report_dict = classification_report(labels, preds,
                                         target_names=class_names,
                                         output_dict=True, zero_division=0)
    print("\n" + report_str)

    path_txt = os.path.join(out_dir, "classification_report.txt")
    with open(path_txt, "w") as f:
        f.write(report_str)

    path_json = os.path.join(out_dir, "classification_report.json")
    with open(path_json, "w") as f:
        json.dump(report_dict, f, indent=2)

    print(f"  Saved {path_txt}")
    print(f"  Saved {path_json}")
    return report_dict


def plot_sample_predictions(paths, labels, preds, probs, class_names, out_dir,
                            n_correct=4, n_incorrect=4):
    labels = np.array(labels)
    preds  = np.array(preds)
    probs  = np.array(probs)

    correct_idx   = np.where(labels == preds)[0]
    incorrect_idx = np.where(labels != preds)[0]
    np.random.shuffle(correct_idx)
    np.random.shuffle(incorrect_idx)

    chosen = list(correct_idx[:n_correct]) + list(incorrect_idx[:n_incorrect])
    if not chosen:
        print("  No samples for prediction grid.")
        return

    n_cols = 4
    n_rows = math.ceil(len(chosen) / n_cols)
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(4 * n_cols, 4.2 * n_rows))
    axes = np.array(axes).reshape(-1)

    for ax_idx, idx in enumerate(chosen):
        ax = axes[ax_idx]
        ax.imshow(Image.open(paths[idx]).convert("RGB"))
        true_name  = class_names[labels[idx]]
        pred_name  = class_names[preds[idx]]
        conf       = probs[idx][preds[idx]]
        color      = "green" if labels[idx] == preds[idx] else "red"
        ax.set_title(f"True: {true_name}  |  Pred: {pred_name}\nConf: {conf:.2%}",
                     color=color, fontsize=10)
        ax.axis("off")

    for ax_idx in range(len(chosen), len(axes)):
        axes[ax_idx].axis("off")

    plt.tight_layout()
    path = os.path.join(out_dir, "sample_predictions.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"  Saved {path}")


def generate_full_report(history, test_result, class_names, out_dir):
    ensure_dir(out_dir)
    print("\n-- Generating performance report --")
    plot_accuracy_curve(history, out_dir)
    plot_loss_curve(history, out_dir)
    plot_confusion_matrix(test_result["labels"], test_result["preds"],
                          class_names, out_dir)
    save_classification_report(test_result["labels"], test_result["preds"],
                               class_names, out_dir)
    if "paths" in test_result:
        plot_sample_predictions(
            test_result["paths"], test_result["labels"],
            test_result["preds"],  test_result["probs"],
            class_names, out_dir)
    print(f"\nAll reports saved to: {out_dir}")


# ─────────────────────────────────────────────
# 12. MAIN TRAINING  (single 70/15/15 split)
# ─────────────────────────────────────────────

def _save_checkpoint(model, val_result, cfg):
    torch.save({
        "model_state"      : model.state_dict(),
        "val_acc"          : float(val_result["acc"]),
        "bal_acc"          : float(val_result["bal_acc"]),
        "class_names"      : CLASS_NAMES,
        "conf_threshold"   : cfg["conf_threshold"],
        "entropy_threshold": cfg["entropy_threshold"],
        "img_size"         : cfg["img_size"],
    }, cfg["model_out"])


def train(cfg):
    set_seed(cfg["seed"])
    device = cfg["device"]
    ensure_dir(cfg["output_dir"])
    print(f"\nDevice: {device}")
    if device == "cpu":
        print("  WARNING: GPU not found — training will be very slow.")

    image_map = build_image_map(cfg["dataset_dir"], cfg["image_dirs"])
    df        = pd.read_csv(cfg["csv_path"])
    print(f"CSV rows: {len(df)}")
    print(df["diagnostic"].value_counts().to_string(), "\n")

    # Train OOD binary classifier first (or skip if no non-skin data)
    train_ood_classifier(cfg, image_map)

    # ── Stratified split ──
    train_df, temp_df = train_test_split(
        df, test_size=(cfg["val_size"] + cfg["test_size"]),
        stratify=df["diagnostic"], random_state=cfg["seed"])
    relative_test = cfg["test_size"] / (cfg["val_size"] + cfg["test_size"])
    val_df, test_df = train_test_split(
        temp_df, test_size=relative_test,
        stratify=temp_df["diagnostic"], random_state=cfg["seed"])
    print(f"Split -> train: {len(train_df)} | val: {len(val_df)} | test: {len(test_df)}\n")

    train_tf, val_tf = get_transforms(cfg["img_size"])
    train_ds = SkinDiseaseDataset(train_df, image_map, train_tf)
    val_ds   = SkinDiseaseDataset(val_df,   image_map, val_tf)
    test_ds  = SkinDiseaseDataset(test_df,  image_map, val_tf)

    sampler      = make_weighted_sampler(train_ds.df)
    train_loader = DataLoader(train_ds, batch_size=cfg["batch_size"],
                              sampler=sampler, num_workers=2, pin_memory=True)
    val_loader   = DataLoader(val_ds,  batch_size=cfg["batch_size"],
                              shuffle=False, num_workers=2, pin_memory=True)
    test_loader  = DataLoader(test_ds, batch_size=cfg["batch_size"],
                              shuffle=False, num_workers=2, pin_memory=True)

    class_weights = compute_class_weights(train_ds.df, device)
    criterion     = FocalLoss(class_weights=class_weights, gamma=2.0,
                              label_smoothing=0.05, num_classes=cfg["num_classes"])
    model         = build_disease_model(cfg["num_classes"], device)

    history = {
        "train_loss": [], "val_loss": [],
        "train_acc" : [], "val_acc" : [],
        "warmup_epochs": cfg["epochs_warmup"],
    }
    best_bal_acc      = 0.0
    epochs_no_improve = 0

    # ════════════════════════════════════════
    # Stage 1 — Warmup  (backbone frozen)
    # ════════════════════════════════════════
    print("=== Stage 1: Warmup (backbone frozen) ===")
    optimizer = optim.AdamW(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=cfg["lr_warmup"], weight_decay=cfg["weight_decay"])

    for epoch in range(cfg["epochs_warmup"]):
        lr = get_lr(epoch, cfg["epochs_warmup"],
                    cfg["lr_warmup"], cfg["lr_warmup"] / 10, warmup_epochs=1)
        for pg in optimizer.param_groups:
            pg["lr"] = lr

        train_loss, train_acc = train_one_epoch(
            model, train_loader, criterion, optimizer, device)
        val_result = validate(model, val_loader, criterion, device)

        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_result["loss"])
        history["train_acc"].append(train_acc)
        history["val_acc"].append(val_result["acc"])

        print(f"  [Warmup] Ep {epoch+1:2d}/{cfg['epochs_warmup']} | "
              f"Train {train_loss:.4f}/{train_acc:.2%} | "
              f"Val {val_result['loss']:.4f}/{val_result['acc']:.2%} | "
              f"BalAcc {val_result['bal_acc']:.2%} | LR {lr:.2e}")

        if val_result["bal_acc"] > best_bal_acc:
            best_bal_acc = val_result["bal_acc"]
            _save_checkpoint(model, val_result, cfg)

    # ════════════════════════════════════════
    # Stage 2 — Fine-tune  (all layers)
    # ════════════════════════════════════════
    print("\n=== Stage 2: Fine-tuning (full backbone) ===")
    unfreeze_backbone(model)
    optimizer = optim.AdamW(model.parameters(),
                            lr=cfg["lr_finetune"],
                            weight_decay=cfg["weight_decay"])

    for epoch in range(cfg["epochs_finetune"]):
        lr = get_lr(epoch, cfg["epochs_finetune"],
                    cfg["lr_finetune"], cfg["min_lr"], warmup_epochs=2)
        for pg in optimizer.param_groups:
            pg["lr"] = lr

        train_loss, train_acc = train_one_epoch(
            model, train_loader, criterion, optimizer, device)
        val_result = validate(model, val_loader, criterion, device)

        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_result["loss"])
        history["train_acc"].append(train_acc)
        history["val_acc"].append(val_result["acc"])

        print(f"  [Finetune] Ep {epoch+1:2d}/{cfg['epochs_finetune']} | "
              f"Train {train_loss:.4f}/{train_acc:.2%} | "
              f"Val {val_result['loss']:.4f}/{val_result['acc']:.2%} | "
              f"BalAcc {val_result['bal_acc']:.2%} | LR {lr:.2e}")

        if val_result["bal_acc"] > best_bal_acc:
            best_bal_acc      = val_result["bal_acc"]
            epochs_no_improve = 0
            _save_checkpoint(model, val_result, cfg)
            print(f"    -> New best saved (bal_acc {best_bal_acc:.2%})")
        else:
            epochs_no_improve += 1
            if epochs_no_improve >= cfg["early_stop_patience"]:
                print(f"  Early stop — no improvement for "
                      f"{cfg['early_stop_patience']} epochs.")
                break

    # ════════════════════════════════════════
    # Final evaluation on held-out TEST set
    # ════════════════════════════════════════
    print("\n=== Final Evaluation on Test Set ===")
    ckpt = torch.load(cfg["model_out"], map_location=device, weights_only=False)
    model.load_state_dict(ckpt["model_state"])
    test_result = validate(model, test_loader, criterion, device,
                           collect_paths=True)
    print(f"  Test Accuracy         : {accuracy_score(test_result['labels'], test_result['preds']):.2%}")
    print(f"  Test Balanced Accuracy: {test_result['bal_acc']:.2%}")

    generate_full_report(history, test_result, CLASS_NAMES, cfg["output_dir"])

    return model, history, test_result


# ─────────────────────────────────────────────
# 13. OOD HELPERS + INFERENCE
# ─────────────────────────────────────────────

def prediction_entropy(probs):
    eps = 1e-9
    return -(probs * (probs + eps).log()).sum().item()


def load_ood_classifier(ood_model_path, device):
    if ood_model_path is None or not os.path.exists(ood_model_path):
        return None
    m = build_ood_model(device)
    m.load_state_dict(torch.load(ood_model_path, map_location=device,
                                 weights_only=False))
    m.eval()
    return m


def ood_binary_check(ood_model, image, device, img_size=224):
    if ood_model is None:
        return True  # no binary gate → pass through to threshold check
    _, val_tf = get_transforms(img_size)
    tensor = val_tf(image).unsqueeze(0).to(device)
    with torch.no_grad():
        prob = torch.sigmoid(ood_model(tensor).squeeze()).item()
    return prob >= 0.5


def threshold_check(probs, conf_threshold, entropy_threshold):
    return (probs.max().item() >= conf_threshold and
            prediction_entropy(probs) <= entropy_threshold)


def load_disease_model(model_path, device):
    global CLASS_NAMES
    ckpt = torch.load(model_path, map_location=device, weights_only=False)
    
    # Dynamically determine the number of classes from checkpoint weights
    model_state = ckpt["model_state"]
    if "classifier.5.bias" in model_state:
        num_classes = model_state["classifier.5.bias"].shape[0]
    elif "classifier.5.weight" in model_state:
        num_classes = model_state["classifier.5.weight"].shape[0]
    else:
        num_classes = len(ckpt.get("class_names", CLASS_NAMES))
        
    m = build_disease_model(num_classes, device, pretrained=False)
    m.load_state_dict(model_state)
    m.eval()
    
    # Update global CLASS_NAMES and LABEL_MAP to match checkpoint
    if "class_names" in ckpt:
        CLASS_NAMES.clear()
        CLASS_NAMES.extend(ckpt["class_names"])
        LABEL_MAP.clear()
        LABEL_MAP.update({name: i for i, name in enumerate(CLASS_NAMES)})
        
    thresholds = {
        "conf"    : ckpt.get("conf_threshold",    0.55),
        "entropy" : ckpt.get("entropy_threshold", 1.3),
        "img_size": ckpt.get("img_size",          300),
    }
    return m, thresholds


def predict_image(model, ood_model, image_path, thresholds,
                  device="cpu", use_tta=True):
    """
    Full inference pipeline:
      Gate 1 — binary OOD classifier     → reject if not skin
      Disease model + optional TTA
      Gate 2 — confidence/entropy check  → reject if uncertain
    Returns a dict with disease, confidence, all_scores, is_skin.
    """
    img_size = thresholds["img_size"]
    image    = Image.open(image_path).convert("RGB")

    # Gate 1
    if not ood_binary_check(ood_model, image, device):
        return {
            "disease"   : "NOT_SKIN", "confidence": 0.0,
            "all_scores": {n: 0.0 for n in CLASS_NAMES},
            "is_skin"   : False,
            "message"   : "Rejected: image does not appear to be a skin lesion.",
        }

    tf_list = get_tta_transforms(img_size) if use_tta else [
        transforms.Compose([
            transforms.Resize((img_size, img_size)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ])
    ]

    all_probs = []
    for tf in tf_list:
        tensor = tf(image).unsqueeze(0).to(device)
        with torch.no_grad():
            all_probs.append(torch.softmax(model(tensor), dim=1)[0])
    probs = torch.stack(all_probs).mean(0)

    # Gate 2
    if not threshold_check(probs, thresholds["conf"], thresholds["entropy"]):
        return {
            "disease"   : "NOT_SKIN",
            "confidence": round(probs.max().item(), 4),
            "all_scores": {n: round(probs[i].item(), 4)
                           for i, n in enumerate(CLASS_NAMES)},
            "is_skin"   : False,
            "message"   : "Rejected: model confidence too low for a diagnosis.",
        }

    top_idx = probs.argmax().item()
    return {
        "disease"   : CLASS_NAMES[top_idx],
        "confidence": round(probs[top_idx].item(), 4),
        "all_scores": {n: round(probs[i].item(), 4)
                       for i, n in enumerate(CLASS_NAMES)},
        "is_skin"   : True,
    }
# ─────────────────────────────────────────────
# 14. SINGLETON MODEL HOLDER
# ─────────────────────────────────────────────

class SkinDiseaseModel:
    """Loads the trained checkpoint once and exposes a predict method."""

    def __init__(self):
        self.model: nn.Module | None = None
        self.ood_model: nn.Module | None = None
        self.thresholds = {
            "conf": 0.55,
            "entropy": 1.3,
            "img_size": 300,
        }
        self.device: str = "cpu"
        self.loaded: bool = False

    def load(self, model_path: str, device: str = "cpu") -> None:
        """Load the disease model and OOD classifier if available."""
        self.device = device
        
        # Load main disease model
        self.model, self.thresholds = load_disease_model(model_path, device)
        
        # Try loading OOD classifier if present
        dir_name = os.path.dirname(model_path)
        ood_path = os.path.join(dir_name, "ood_classifier.pth")
        if not os.path.exists(ood_path):
            ood_path = os.path.join(dir_name, "skin_model_outputs", "ood_classifier.pth")
            
        if os.path.exists(ood_path):
            self.ood_model = load_ood_classifier(ood_path, device)
            print(f"  ✓ OOD Classifier loaded from {ood_path}")
        else:
            self.ood_model = None
            print("  ℹ No OOD Classifier found; relying on confidence/entropy threshold checks.")
            
        self.loaded = True
        print(f"  ✓ SkinDiseaseModel loaded successfully on {device}")

    def predict(self, image: Image.Image) -> dict:
        """
        Run inference on a PIL Image.
        Returns a dictionary formatted for the API and Streamlit UI.
        """
        if not self.loaded:
            raise RuntimeError("Model not loaded. Call load() first.")

        # Map long class names from checkpoint to clean, short API codes
        MAP_LONG_TO_SHORT = {
            "Melanoma": "MEL",
            "Melanocytic Nevi (Moles)": "NEV",
            "Basal Cell Carcinoma": "BCC",
            "Actinic Keratosis": "ACK",
            "Benign Keratosis": "SEK",
            "Dermatofibroma": "DF",
            "Vascular Lesions": "VASC",
            "Eczema / Dermatitis": "Eczema",
            "Psoriasis": "Psoriasis",
            "Tinea / Fungal Infection": "Fungal"
        }

        # Gate 1 — binary OOD check
        if not ood_binary_check(self.ood_model, image, self.device):
            return {
                "predicted_class": "OOD",
                "disease_name": "Out of Domain / Not Skin",
                "severity": "low",
                "confidence": 0.0,
                "all_scores": {MAP_LONG_TO_SHORT.get(n, n): 0.0 for n in CLASS_NAMES},
                "is_skin": False,
                "message": "Rejected: image does not appear to be a skin lesion.",
            }

        img_size = self.thresholds["img_size"]
        tf_list = get_tta_transforms(img_size)

        all_probs = []
        for tf in tf_list:
            tensor = tf(image).unsqueeze(0).to(self.device)
            with torch.no_grad():
                all_probs.append(torch.softmax(self.model(tensor), dim=1)[0])
        probs = torch.stack(all_probs).mean(0)

        # Gate 2 — confidence/entropy threshold check
        if not threshold_check(probs, self.thresholds["conf"], self.thresholds["entropy"]):
            top_idx = probs.argmax().item()
            top_class = CLASS_NAMES[top_idx]
            info = CLASS_INFO.get(top_class, {"full_name": top_class, "severity": "moderate"})
            return {
                "predicted_class": "UNCERTAIN",
                "disease_name": "Uncertain / Low Confidence",
                "severity": "low",
                "confidence": round(probs[top_idx].item(), 4),
                "all_scores": {MAP_LONG_TO_SHORT.get(n, n): round(probs[i].item(), 4) for i, n in enumerate(CLASS_NAMES)},
                "is_skin": False,
                "message": f"Rejected: model confidence too low for a diagnosis. Most likely: {info['full_name']} ({probs[top_idx].item():.1%})",
            }

        top_idx = probs.argmax().item()
        top_class = CLASS_NAMES[top_idx]
        info = CLASS_INFO.get(top_class, {"full_name": top_class, "severity": "moderate"})

        return {
            "predicted_class": MAP_LONG_TO_SHORT.get(top_class, top_class),
            "disease_name": info["full_name"],
            "severity": info["severity"],
            "confidence": round(probs[top_idx].item(), 4),
            "all_scores": {
                MAP_LONG_TO_SHORT.get(name, name): round(probs[i].item(), 4)
                for i, name in enumerate(CLASS_NAMES)
            },
            "is_skin": True,
        }


# ── Module-level singleton ─────────────────────────────────────────

skin_model = SkinDiseaseModel()


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

if __name__ == "__main__":
    train(CONFIG)
