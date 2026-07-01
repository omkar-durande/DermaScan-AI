<div align="center">

# 🩺 DermaScan AI

**AI-powered skin disease detection — Flutter App + FastAPI Backend**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com/)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.4-EE4C2C?style=flat-square&logo=pytorch)](https://pytorch.org/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?style=flat-square&logo=firebase)](https://firebase.google.com/)
[![HuggingFace](https://img.shields.io/badge/🤗%20HuggingFace-Spaces-FFD21E?style=flat-square)](https://huggingface.co/spaces/omkardurande/dermascan-api)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

*Snap a photo → get an AI diagnosis → find a nearby hospital, all in seconds.*

</div>

---

## 📱 App Screenshots

<p align="center">
  <img src="./fastapi_backend/screenshots/01_hospitals_list.jpg" width="18%" alt="Nearby Hospitals List"/>
  <img src="./fastapi_backend/screenshots/02_uv_exposure.jpg" width="18%" alt="UV Exposure"/>
  <img src="./fastapi_backend/screenshots/03_hospitals_map.jpg" width="18%" alt="Hospitals Map"/>
  <img src="./fastapi_backend/screenshots/04_home_remedies.jpg" width="18%" alt="Home Remedies"/>
  <img src="./fastapi_backend/screenshots/05_remedy_detail.jpg" width="18%" alt="Remedy Detail"/>
</p>

| Nearby Hospitals | UV Exposure | Hospitals Map | Home Remedies | Remedy Detail |
|:---:|:---:|:---:|:---:|:---:|
| 64 hospitals & clinics | Live UV index | OpenStreetMap | Severity-tagged | Step-by-step |

---

## 📌 Overview

**DermaScan AI** is a full-stack mobile health application that uses deep learning to classify skin lesions from dermoscopic images. The system combines a **Flutter mobile app** (Android/iOS) with a **FastAPI backend** running an **EfficientNet-B3** model trained on the clinical **PAD-UFES-20** dataset.

> ⚕️ **Medical Disclaimer:** This tool is for educational and research purposes only. It is **not** a substitute for professional medical diagnosis.

---

## 🗂️ Repository Structure

```
DermaScan-AI/
│
├── 📁 dermascan_ai/              # Flutter Mobile App (Android & iOS)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/              # All UI screens
│   │   ├── services/             # Firebase, API, PDF, Gemini AI
│   │   ├── providers/            # State management
│   │   ├── models/               # Data models
│   │   └── widgets/              # Reusable components
│   ├── assets/
│   │   ├── images/               # App logo & images
│   │   └── animations/           # Lottie animations
│   └── pubspec.yaml
│
└── 📁 fastapi_backend/           # Python AI Backend
    ├── main.py                   # FastAPI routes & endpoints
    ├── model.py                  # EfficientNet-B3 model + training
    ├── app_ui.py                 # Streamlit monitoring dashboard
    ├── requirements.txt
    ├── Dockerfile
    └── screenshots/              # App screenshots
```

---

## ✨ Features

### 📱 Mobile App (Flutter)
| Feature | Description |
|---|---|
| 📷 **AI Skin Scan** | Camera/gallery → real-time AI classification |
| 🔐 **Authentication** | Firebase Auth with OTP & email verification |
| 🏥 **Nearby Hospitals** | Map + list of hospitals & clinics by distance |
| 🌞 **UV Exposure** | Live UV index with sun protection advice |
| 💊 **Home Remedies** | Condition-specific remedy suggestions |
| 🤖 **AI Chat** | Gemini-powered dermatology assistant |
| 📋 **Scan History** | Full scan log with confidence scores |
| 📄 **PDF Export** | Generate shareable medical report PDFs |

### ⚙️ Backend (FastAPI)
| Feature | Description |
|---|---|
| 🔬 **AI Inference** | EfficientNet-B3 classifies 6 skin lesion types |
| ⚡ **Fast Response** | Sub-second prediction with TTA |
| 🛡️ **OOD Rejection** | Rejects non-skin images |
| 📊 **Scan CRUD** | Save, retrieve & delete scan records |
| 🐳 **Docker Ready** | Deploy on HuggingFace Spaces |

---

## 🧠 Supported Disease Classes

| Code | Disease | Severity |
|------|---------|----------|
| `NEV` | Melanocytic Nevi (Mole) | 🟢 Low |
| `BCC` | Basal Cell Carcinoma | 🔴 High |
| `ACK` | Actinic Keratosis | 🟡 Medium |
| `SEK` | Seborrheic Keratosis | 🟢 Low |
| `SCC` | Squamous Cell Carcinoma | 🔴 High |
| `MEL` | Melanoma | 🔴 Critical |

---

## 🚀 Getting Started

### Flutter App
```bash
cd dermascan_ai
flutter pub get
# Add google-services.json for Firebase
flutter run
```

### FastAPI Backend
```bash
cd fastapi_backend
pip install -r requirements.txt
# Add skin_model.pth weights
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Docker
```bash
cd fastapi_backend
docker build -t dermascan-api .
docker run -p 7860:7860 dermascan-api
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x, Dart |
| State | Provider |
| Backend | FastAPI, Python 3.11 |
| AI Model | EfficientNet-B3, PyTorch 2.4 |
| Auth & DB | Firebase Auth, Firestore |
| Maps | flutter_map (OpenStreetMap) |
| AI Chat | Google Gemini API |
| Hosting | HuggingFace Spaces, Docker |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

Made with ❤️ by [Omkar Durande](https://github.com/omkar-durande)

⭐ **Star this repo if you find it useful!**

</div>
