"""
Quick Streamlit UI for testing the Skin Disease Detection API.
Run:  streamlit run app_ui.py
(Make sure the FastAPI server is running on port 8000 first)
"""

import streamlit as st
import requests
from PIL import Image
import io

API_URL = "http://localhost:8000"

# ── Page config ────────────────────────────────────────────────────

st.set_page_config(
    page_title="Skin Disease Detector",
    page_icon="🔬",
    layout="centered",
)

# ── Custom CSS ─────────────────────────────────────────────────────

st.markdown("""
<style>
    .main { max-width: 700px; margin: auto; }
    .result-card {
        background: linear-gradient(135deg, #1e1e2f, #2a2a40);
        border-radius: 16px;
        padding: 24px;
        color: white;
        margin: 16px 0;
    }
    .disease-name {
        font-size: 28px;
        font-weight: 700;
        margin-bottom: 4px;
    }
    .severity-low { color: #4ade80; }
    .severity-moderate { color: #facc15; }
    .severity-high { color: #f97316; }
    .severity-critical { color: #ef4444; }
    .confidence-big {
        font-size: 48px;
        font-weight: 800;
        background: linear-gradient(90deg, #60a5fa, #a78bfa);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }
</style>
""", unsafe_allow_html=True)

# ── Header ─────────────────────────────────────────────────────────

st.markdown("# 🔬 Skin Disease Detector")
st.markdown("Upload a skin lesion image to get an AI-powered diagnosis.")
st.markdown("---")

# ── Check API health ──────────────────────────────────────────────

try:
    health = requests.get(f"{API_URL}/health", timeout=3).json()
    if health.get("model_loaded"):
        st.success("✅ API is running & model is loaded")
    else:
        st.warning("⚠️ API is running but model is NOT loaded. Place `skin_model.pth` and restart.")
except requests.exceptions.ConnectionError:
    st.error("❌ Cannot connect to API at `localhost:8000`. Start it with: `uvicorn main:app --reload`")
    st.stop()

# ── Upload ─────────────────────────────────────────────────────────

uploaded = st.file_uploader(
    "Choose an image",
    type=["jpg", "jpeg", "png", "webp"],
    help="Max 10 MB. Supported: JPG, PNG, WebP",
)

if uploaded:
    image = Image.open(uploaded)

    col1, col2 = st.columns([1, 1])
    with col1:
        st.image(image, caption="Uploaded image", use_container_width=True)

    # ── Call API ───────────────────────────────────────────────────

    with st.spinner("Analyzing..."):
        files = {"file": (uploaded.name, uploaded.getvalue(), uploaded.type)}
        try:
            resp = requests.post(f"{API_URL}/predict", files=files, timeout=30)
        except requests.exceptions.ConnectionError:
            st.error("Lost connection to API.")
            st.stop()

    if resp.status_code != 200:
        st.error(f"API error {resp.status_code}: {resp.json().get('detail', resp.text)}")
        st.stop()

    data = resp.json()
    pred = data["prediction"]

    # ── Results ────────────────────────────────────────────────────

    severity = pred["severity"]
    sev_class = f"severity-{severity}"
    sev_emoji = {"low": "🟢", "moderate": "🟡", "high": "🟠", "critical": "🔴"}[severity]

    with col2:
        st.markdown(f"""
        <div class="result-card">
            <div class="confidence-big">{pred['confidence']:.1%}</div>
            <div class="disease-name">{pred['disease_name']}</div>
            <div style="font-size:14px; opacity:0.7;">Code: {pred['predicted_class']}</div>
            <div style="margin-top:12px; font-size:16px;">
                Severity: {sev_emoji} <span class="{sev_class}" style="font-weight:600;">{severity.upper()}</span>
            </div>
            <div style="margin-top:8px; font-size:13px; opacity:0.5;">
                Inference: {data['inference_time_ms']} ms
            </div>
        </div>
        """, unsafe_allow_html=True)

    # ── Score breakdown ────────────────────────────────────────────

    st.markdown("### 📊 All Class Probabilities")

    scores = pred["all_scores"]
    sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)

    CLASS_FULL = {
        "NEV": "Melanocytic Nevus",
        "BCC": "Basal Cell Carcinoma",
        "ACK": "Actinic Keratosis",
        "SEK": "Seborrheic Keratosis",
        "SCC": "Squamous Cell Carcinoma",
        "MEL": "Melanoma",
        "DF": "Dermatofibroma",
        "VASC": "Vascular Lesions",
        "Eczema": "Eczema / Dermatitis",
        "Psoriasis": "Psoriasis",
        "Fungal": "Tinea / Fungal Infection"
    }

    for code, score in sorted_scores:
        label = f"{code} — {CLASS_FULL.get(code, code)}"
        st.progress(score, text=f"{label}:  **{score:.2%}**")

    # ── Disclaimer ─────────────────────────────────────────────────

    st.markdown("---")
    st.caption(
        "⚠️ **Disclaimer**: This is an AI research tool, not a medical device. "
        "Always consult a dermatologist for clinical diagnosis."
    )
