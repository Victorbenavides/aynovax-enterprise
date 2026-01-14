import os
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import HuggingFaceEmbeddings

class VectorEngine:
    """
    Engine responsible for embedding (vectorizing) text and managing the ChromaDB storage.
    """
    
    def __init__(self):
        # INITIALIZE MULTILINGUAL EMBEDDINGS
        # We use a specific model capable of cross-lingual understanding (English <-> Spanish)
        # to ensure the system works regardless of the input/output language.
        print("--- [INFO] Loading Multilingual Embeddings Model... ---")
        try:
            self.embeddings = HuggingFaceEmbeddings(
                model_name="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
            )
            self.persist_directory = "chroma_db_store"
            print("--- [INFO] Embeddings Model Loaded Successfully ---")
        except Exception as e:
            print(f"--- [CRITICAL] Failed to load embedding model: {e} ---")
            raise e

    def process_and_index(self, documents: list, filename: str):
        """
        Splits documents into chunks and indexes them into the vector database.
        
        Args:
            documents (list): List of Document objects with metadata.
            filename (str): The name of the source file (for logging/metadata).
            
        Returns:
            dict: Statistics about the indexing process.
        """
        try:
            # 1. SMART CHUNKING
            # We use a large chunk size (1000) with significant overlap (200) 
            # to maintain context across sentence boundaries.
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200, 
                separators=["\n\n", "\n", ".", "!", "?", ",", " ", ""],
                length_function=len,
            )
            
            # split_documents preserves the 'metadata' (page numbers) from the input
            chunks = text_splitter.split_documents(documents)
            
            # Enrich metadata with filename ensuring traceability
            for chunk in chunks:
                chunk.metadata["filename"] = filename

            # 2. PERSIST TO CHROMADB
            print(f"--- [INFO] Indexing: {len(chunks)} chunks generated for {filename} ---")
            
            vectordb = Chroma.from_documents(
                documents=chunks,
                embedding=self.embeddings,
                persist_directory=self.persist_directory
            )
            
            # Force save to disk
            vectordb.persist()
            print("--- [SUCCESS] Indexing Complete ---")
            
            return {
                "total_chunks": len(chunks),
                "storage_path": self.persist_directory
            }
            
        except Exception as e:
            print(f"--- [ERROR] Vector Engine Indexing Error: {e} ---")
            raise e

    def search_similar(self, query: str, k: int = 6):
        """
        Retrieves the most relevant text chunks for a given query.
        
        Args:
            query (str): The user's question.
            k (int): Number of chunks to retrieve (Default 6 for broader context).
            
        Returns:
            list[Document]: List of relevant documents found in the DB.
        """
        try:
            vectordb = Chroma(
                persist_directory=self.persist_directory, 
                embedding_function=self.embeddings
            )
            
            # Perform similarity search
            results = vectordb.similarity_search(query, k=k)
            return results
            
        except Exception as e:
            print(f"--- [ERROR] Search Operation Failed: {e} ---")
            return []