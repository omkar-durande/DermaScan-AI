"""
Skin Disease Detection — FastAPI Server
=========================================
Endpoints:
    POST /predict       – upload an image → get prediction
    GET  /health        – server & model health check
    GET  /classes       – list of supported disease classes
    POST /scans         – save a new scan record
    GET  /scans/{user_id} – get scan history for a user
    DELETE /scans/{id}  – delete a scan record
"""

import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
import io
import json

from model import skin_model, CLASS_NAMES, CLASS_INFO

# ── Configuration ──────────────────────────────────────────────────

MODEL_PATH = os.getenv("MODEL_PATH", "skin_model.pth")
DEVICE = os.getenv("DEVICE", "cpu")
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
SCANS_FILE = "scans_db.json"  # Simple file-based storage


# ── In-memory scan storage (replace with Firestore in production) ──

def _load_scans():
    if os.path.exists(SCANS_FILE):
        with open(SCANS_FILE, "r") as f:
            return json.load(f)
    return {}


def _save_scans(scans):
    with open(SCANS_FILE, "w") as f:
        json.dump(scans, f, indent=2)


# ── Pydantic models ───────────────────────────────────────────────

class ScanRecord(BaseModel):
    userId: str
    disease: str
    fullName: str
    severity: str
    confidence: float
    allScores: dict
    imageUrl: Optional[str] = None
    warning: Optional[str] = None
    notes: Optional[str] = None
    timestamp: int


# ── Lifespan (load model at startup) ──────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the model once when the server starts."""
    if not os.path.exists(MODEL_PATH):
        print(f"  ✗ Model file not found: {MODEL_PATH}")
        print("    Copy your trained skin_model.pth into the fastapi_backend/ folder.")
    else:
        skin_model.load(MODEL_PATH, device=DEVICE)
    yield


# ── App setup ──────────────────────────────────────────────────────

app = FastAPI(
    title="Skin Disease Detection API",
    description="Upload a dermoscopic image to classify skin lesions into 6 categories "
                "(NEV, BCC, ACK, SEK, SCC, MEL) using an EfficientNet-B0 model "
                "trained on the PAD-UFES-20 dataset.",
    version="2.0.0",
    lifespan=lifespan,
)

# Allow cross-origin requests (adjust origins for production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Endpoints ──────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Check if the server is running and the model is loaded."""
    return {
        "status": "ok",
        "model_loaded": skin_model.loaded,
        "device": DEVICE,
        "classes": CLASS_NAMES,
    }


@app.get("/classes")
async def classes():
    """Return the list of supported disease classes with metadata."""
    return {
        "num_classes": len(CLASS_NAMES),
        "classes": {
            code: {
                "index": i,
                "full_name": CLASS_INFO[code]["full_name"],
                "severity": CLASS_INFO[code]["severity"],
            }
            for i, code in enumerate(CLASS_NAMES)
        },
    }


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    """
    Upload a skin lesion image and get a prediction.

    - **file**: JPEG, PNG, or WebP image (max 10 MB)

    Returns the predicted disease class, confidence score,
    severity level, and per-class probabilities.
    """
    # ── Validate model is ready ──
    if not skin_model.loaded:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Ensure skin_model.pth is present and restart the server.",
        )

    # ── Validate file type ──
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file.content_type}. "
                   f"Allowed: {', '.join(ALLOWED_TYPES)}",
        )

    # ── Read and validate file size ──
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"File too large ({len(contents) / 1024 / 1024:.1f} MB). "
                   f"Max allowed: {MAX_FILE_SIZE / 1024 / 1024:.0f} MB.",
        )

    # ── Open image ──
    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Could not decode the uploaded image.")

    # ── Validate image dimensions ──
    if image.width < 100 or image.height < 100:
        raise HTTPException(
            status_code=400,
            detail="Image is too small. Please take a clearer photo (min 100x100px).",
        )

    # ── Run inference ──
    start = time.time()
    result = skin_model.predict(image)
    inference_ms = round((time.time() - start) * 1000, 1)

    return JSONResponse(content={
        "success": True,
        "prediction": result,
        "inference_time_ms": inference_ms,
    })


# ── Scan CRUD Endpoints ───────────────────────────────────────────

@app.post("/scans")
async def create_scan(scan: ScanRecord):
    """Save a new scan record."""
    scans = _load_scans()
    scan_id = str(uuid.uuid4())
    scans[scan_id] = scan.model_dump()
    _save_scans(scans)
    return {"id": scan_id, "message": "Scan saved successfully"}


@app.get("/scans/{user_id}")
async def get_scans(user_id: str):
    """Get all scan records for a specific user."""
    scans = _load_scans()
    user_scans = [
        {"id": sid, **data}
        for sid, data in scans.items()
        if data.get("userId") == user_id
    ]
    # Sort by timestamp descending
    user_scans.sort(key=lambda x: x.get("timestamp", 0), reverse=True)
    return {"scans": user_scans, "count": len(user_scans)}


@app.delete("/scans/{scan_id}")
async def delete_scan(scan_id: str):
    """Delete a scan record by ID."""
    scans = _load_scans()
    if scan_id not in scans:
        raise HTTPException(status_code=404, detail="Scan not found")
    del scans[scan_id]
    _save_scans(scans)
    return {"message": "Scan deleted successfully"}


# ── Run with: uvicorn main:app --reload ───────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
