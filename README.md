# 🧠 AynovaX Enterprise | Private AI Document Analyst

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B) ![Python](https://img.shields.io/badge/Backend-FastAPI-3776AB) ![AI](https://img.shields.io/badge/AI-Ollama%20%7C%20Llama3.2-orange)

> **[🇺🇸 English](#-english-description) | [🇪🇸 Español](#-descripción-en-español)**
>
<img width="1235" height="669" alt="image" src="https://github.com/user-attachments/assets/4556f435-f686-46c8-926e-af2c4520c37e" />




---

<a name="-english-description"></a>
## 🇺🇸 English Description

**AynovaX** is a secure, cross-platform **RAG (Retrieval-Augmented Generation)** system designed for intelligent document analysis. Unlike cloud-based solutions, AynovaX processes sensitive data locally using **Ollama** and **Llama 3.2**, ensuring 100% data privacy.

The architecture follows a decoupled **Client-Server** pattern, allowing seamless access from Windows, Android, and Web browsers simultaneously.

### 🚀 Key Features
* **🔒 Total Privacy:** Full offline execution. Your data never leaves your local network.
* **🧠 "Strict Mode" Engine:** Anti-hallucination system designed to answer *only* based on the provided PDF context.
* **⚡ Real-Time Streaming:** Token-by-token response generation (typewriter effect) for a smooth UX.
* **📱 Multi-Platform:** Frontend built with **Flutter** (runs on Desktop, Mobile, and Web).
* **💾 Persistent Memory:** Chat history is stored in a SQL database, allowing you to resume conversations.
* **📄 Advanced Parsing:** Uses `pdfplumber` to accurately read complex layouts, tables, and columns.

### 🛠️ Tech Stack
* **Backend:** Python, FastAPI, LangChain, ChromaDB (Vector Store), SQLite.
* **Frontend:** Flutter (Dart), Material Design 3, Markdown Rendering.
* **AI Model:** Llama 3.2 (via Ollama).

---

<a name="-descripción-en-español"></a>
## 🇪🇸 Descripción en Español

**AynovaX** es una plataforma de **Inteligencia Artificial Local** diseñada para "chatear" con documentos PDF complejos. A diferencia de las soluciones en la nube, AynovaX procesa toda la información de manera local garantizando la privacidad de los datos.

Su arquitectura Cliente-Servidor permite conectar múltiples dispositivos (PC, Celular, Web) a un "cerebro" central que procesa la información en tiempo real.

### 🚀 Características Principales
* **🔒 Privacidad Total:** Ejecución 100% offline. Tus datos nunca salen de tu red local.
* **🧠 Motor "Modo Estricto":** Sistema anti-alucinaciones diseñado para responder *únicamente* con la información del PDF.
* **⚡ Streaming en Tiempo Real:** Respuestas generadas palabra por palabra para una experiencia fluida.
* **📱 Multiplataforma:** Frontend desarrollado en **Flutter** (Windows, Android, iOS y Web).
* **💾 Memoria Persistente:** Historial guardado en base de datos SQL para retomar charlas anteriores.
* **📄 Lectura Avanzada:** Utiliza `pdfplumber` para entender tablas y columnas complejas en los PDFs.

### 🛠️ Tecnologías
* **Backend:** Python, FastAPI, LangChain, ChromaDB (Base Vectorial), SQLite.
* **Frontend:** Flutter (Dart), Material Design 3, Renderizado Markdown.
* **Modelo IA:** Llama 3.2 (vía Ollama).

---

## 📸 Screenshots / Capturas

<img width="1612" height="1022" alt="image" src="https://github.com/user-attachments/assets/91940b07-33c4-4387-ab13-866d0d1fd8ea" />

<img width="1469" height="979" alt="image" src="https://github.com/user-attachments/assets/11789526-e6bd-4a14-af96-b847f11dd370" />


## 🔧 Setup / Instalación

### 1. Backend (Python)

    cd backend
    python -m venv venv
    # Activate venv (Windows: venv\Scripts\activate)
    pip install -r requirements.txt
    python main.py

### 2. Frontend (Flutter)

    cd frontend
    flutter pub get
    # ⚠️ Configure your Local IP in lib/src/services/api_service.dart
    flutter run

---

**Developed by Victor Hugo Benavides - AI Engineer & Full Stack Developer**
