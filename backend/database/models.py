from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from .connection import Base

class DocumentRecord(Base):
    """
    SQL Model for storing Document Metadata.
    """
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String, index=True)
    file_path = Column(String)
    vector_index_path = Column(String)
    upload_date = Column(DateTime, default=datetime.utcnow)

    # Relationship: One Document -> Many Chat Messages
    # cascade="all, delete" means if we delete the document, we delete its chat too.
    messages = relationship("ChatMessage", back_populates="document", cascade="all, delete-orphan")

class ChatMessage(Base):
    """
    SQL Model for storing Chat History per Document.
    """
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    document_id = Column(Integer, ForeignKey("documents.id"))
    role = Column(String)  # 'user' or 'ai'
    content = Column(Text) # The actual message text
    timestamp = Column(DateTime, default=datetime.utcnow)

    # Relationship link
    document = relationship("DocumentRecord", back_populates="messages")