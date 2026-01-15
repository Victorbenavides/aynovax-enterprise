import uvicorn
import asyncio
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
import os

# -------------------------------------------------------------------------
# AI Imports
# -------------------------------------------------------------------------
from langchain_community.llms import Ollama

# -------------------------------------------------------------------------
# Local Imports
# -------------------------------------------------------------------------
from services.doc_processor import DocumentProcessor
from services.vector_engine import VectorEngine
from database.connection import engine, Base, get_db
from database.models import DocumentRecord, ChatMessage

# Initialize Database Tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AynovaX Enterprise Engine",
    description="Professional RAG System with SQL Persistence & Streaming",
    version="8.0.0-strict-english"
)

# CORS Configuration: Allows connections from Localhost and Network devices
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIRECTORY = "data_store"
if not os.path.exists(UPLOAD_DIRECTORY):
    os.makedirs(UPLOAD_DIRECTORY)

vector_engine = VectorEngine()

# CONFIGURATION: Strict Mode
# temperature=0.1 makes the AI factual and less creative (reduces hallucinations).
llm = Ollama(model="llama3.2", temperature=0.1)

# -------------------------------------------------------------------------
# Data Schemas (Pydantic)
# -------------------------------------------------------------------------
class ChatRequest(BaseModel):
    query: str
    document_id: int
    stream: bool = True

class DocumentResponse(BaseModel):
    id: int
    filename: str
    upload_date: str

# -------------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------------
def get_chat_history_as_string(db: Session, doc_id: int, limit: int = 10) -> str:
    """
    Retrieves the last N messages from the database to maintain conversation context.
    """
    messages = db.query(ChatMessage).filter(ChatMessage.document_id == doc_id)\
                 .order_by(ChatMessage.timestamp.asc()).all()
    
    recent_msgs = messages[-limit:] if messages else []
    
    history_str = ""
    for msg in recent_msgs:
        role_label = "User" if msg.role == "user" else "AI"
        history_str += f"{role_label}: {msg.content}\n"
    
    return history_str

def save_message(db: Session, doc_id: int, role: str, content: str):
    """
    Saves a single message to the SQL database.
    """
    new_msg = ChatMessage(document_id=doc_id, role=role, content=content)
    db.add(new_msg)
    db.commit()

# -------------------------------------------------------------------------
# API Endpoints
# -------------------------------------------------------------------------

@app.get("/")
async def health_check():
    return {"system": "AynovaX Enterprise", "status": "online", "mode": "STRICT_CONTEXT_ENGLISH"}

# --- 1. GET ALL DOCUMENTS (For Sidebar) ---
@app.get("/api/v1/documents", response_model=List[DocumentResponse])
async def get_documents(db: Session = Depends(get_db)):
    """
    Returns the list of uploaded documents ordered by date.
    """
    docs = db.query(DocumentRecord).order_by(DocumentRecord.upload_date.desc()).all()
    return [
        DocumentResponse(
            id=doc.id, 
            filename=doc.filename, 
            upload_date=doc.upload_date.strftime("%Y-%m-%d %H:%M:%S")
        ) 
        for doc in docs
    ]

# --- 2. GET CHAT HISTORY (For Context Reloading) ---
@app.get("/api/v1/documents/{doc_id}/chat")
async def get_document_chat_history(doc_id: int, db: Session = Depends(get_db)):
    """
    Returns the full chat history for a specific document.
    """
    messages = db.query(ChatMessage).filter(ChatMessage.document_id == doc_id)\
                 .order_by(ChatMessage.timestamp.asc()).all()
    
    return [{"role": msg.role, "text": msg.content} for msg in messages]

# --- 3. UPLOAD & INGEST ---
@app.post("/api/v1/ingest")
async def ingest_document(file: UploadFile = File(...), db: Session = Depends(get_db)):
    try:
        file_location = f"{UPLOAD_DIRECTORY}/{file.filename}"
        with open(file_location, "wb+") as file_object:
            file_object.write(file.file.read())
            
        documents = []
        if file.filename.endswith(".pdf"):
            print(f"--- [INFO] Deep Scanning PDF: {file.filename} ---")
            # Uses pdfplumber via DocumentProcessor for accurate text extraction
            documents = DocumentProcessor.process_pdf(file_location)
        else:
             raise HTTPException(status_code=400, detail="Only PDFs are supported.")
        
        if not documents:
             raise HTTPException(status_code=400, detail="No extractable text found. Is this an image?")

        # Indexing
        vector_stats = vector_engine.process_and_index(documents, file.filename)

        # Save Metadata to SQL
        new_doc = DocumentRecord(
            filename=file.filename,
            file_path=file_location,
            vector_index_path=vector_stats["storage_path"]
        )
        db.add(new_doc)
        db.commit()
        db.refresh(new_doc)

        return {
            "status": "success",
            "db_id": new_doc.id,
            "filename": new_doc.filename
        }
        
    except Exception as e:
        print(f"--- [CRITICAL ERROR] Ingestion Failed: {e} ---")
        raise HTTPException(status_code=500, detail=str(e))

# --- 4. STRICT CHAT LOGIC ---
@app.post("/api/v1/chat")
async def chat_with_document(request: ChatRequest, db: Session = Depends(get_db)):
    try:
        # 1. Verify Document Exists
        doc_record = db.query(DocumentRecord).filter(DocumentRecord.id == request.document_id).first()
        if not doc_record:
            raise HTTPException(status_code=404, detail="Document ID not found.")

        # 2. Retrieve History
        history_text = get_chat_history_as_string(db, request.document_id)

        # 3. Deep Vector Search (Increased k=10 for deeper context analysis)
        results = vector_engine.search_similar(request.query, k=10) 
        
        context_parts = [f"### CURRENT FILE: {doc_record.filename}"]
        for doc in results:
            page = doc.metadata.get('page', '?')
            context_parts.append(f"[Page {page} Excerpt]: {doc.page_content}")
        context_text = "\n\n".join(context_parts)

        # 4. Save USER message
        save_message(db, request.document_id, "user", request.query)

        # 5. STRICT PROMPT ENGINEERING (Anti-Hallucination)
        prompt_template = """
        ### SYSTEM ROLE:
        You are AynovaX, an intelligent and helpful document assistant. 
        Your goal is to explain the content of the document clearly and comprehensively, based ONLY on the provided context.

        ### INSTRUCTIONS:
        1. **SOURCE OF TRUTH:** Use the "DOCUMENT CONTEXT" below to answer. If the document doesn't have the info, say so politely.
        2. **NO HALLUCINATIONS:** Do not make up facts. (e.g., if the name corresponds to a famous person but the document is a CV of a regular person, stick to the CV).
        3. **LANGUAGE MATCHING (CRITICAL):** - **Analyze the User's Question language.**
           - If the User asks in **Spanish**, answer in **Spanish** (even if the text is English).
           - If the User asks in **English**, answer in **English** (even if the text is Spanish).
           - **Rule:** The output language must ALWAYS match the input question language.
        4. **FORMAT:** Do not repeat the history. Do not start with "User:" or "AI:". Just give the answer.

        ### DOCUMENT CONTEXT:
        {context}

        ### CHAT HISTORY:
        {history}

        ### USER QUESTION: 
        {question}

        ### YOUR ANSWER (In the User's Language):
        """
        formatted_prompt = prompt_template.format(
            context=context_text,
            history=history_text,
            question=request.query
        )

        # 6. Stream Generator
        async def response_generator():
            full_response = ""
            # print(f"--- [DEBUG] Prompt sent to Ollama (first 200 chars): {formatted_prompt[:200]}... ---")
            
            async for chunk in llm.astream(formatted_prompt):
                if chunk:
                    full_response += chunk
                    yield chunk
                    await asyncio.sleep(0.01)

            # 7. Save AI message
            save_message(db, request.document_id, "ai", full_response)

        return StreamingResponse(response_generator(), media_type="text/plain")

    except Exception as e:
        print(f"--- [ERROR] Chat Processing Failed: {e} ---")
        raise HTTPException(status_code=500, detail=str(e))

# --- 5. MANAGEMENT ENDPOINTS ---

@app.delete("/api/v1/documents/{doc_id}/chat")
async def clear_chat_history(doc_id: int, db: Session = Depends(get_db)):
    """
    Clears ONLY the chat history for a specific document.
    """
    db.query(ChatMessage).filter(ChatMessage.document_id == doc_id).delete()
    db.commit()
    return {"status": "success", "message": "Chat history cleared."}

@app.delete("/api/v1/documents/{doc_id}")
async def delete_document(doc_id: int, db: Session = Depends(get_db)):
    """
    Deletes the document, its file, and its chat history.
    """
    doc = db.query(DocumentRecord).filter(DocumentRecord.id == doc_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found.")

    if os.path.exists(doc.file_path):
        os.remove(doc.file_path)

    db.delete(doc)
    db.commit()
    
    return {"status": "success", "message": "Document and history deleted."}

if __name__ == "__main__":
    # Using 127.0.0.1 to avoid [WinError 64] on Windows. 
    # Change to "0.0.0.0" ONLY if you need mobile access and firewall is configured.
    uvicorn.run(app, host="127.0.0.1", port=8000)