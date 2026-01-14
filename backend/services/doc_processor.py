import pdfplumber
from langchain.schema import Document
import os

class DocumentProcessor:
    @staticmethod
    def process_pdf(file_path: str):
        """
        Extracts text from a PDF file using pdfplumber for high accuracy
        (better handling of columns, tables, and headers like in CVs).
        """
        docs = []
        full_text_debug = "" # Variable para ver qué estamos leyendo

        try:
            with pdfplumber.open(file_path) as pdf:
                print(f"--- [PROCESSOR] Reading {len(pdf.pages)} pages from {os.path.basename(file_path)} ---")
                
                for i, page in enumerate(pdf.pages):
                    # Extract text preserving layout
                    text = page.extract_text() or ""
                    
                    # Basic cleaning
                    text = text.strip()
                    
                    if text:
                        # Add to our debug string (first 500 chars)
                        if len(full_text_debug) < 500:
                            full_text_debug += text + "\n"

                        # Create the LangChain Document object
                        # We store page number in metadata for citations
                        docs.append(Document(
                            page_content=text,
                            metadata={
                                "source": file_path,
                                "filename": os.path.basename(file_path),
                                "page": i + 1
                            }
                        ))
            
            # --- DEBUG PRINT ---
            # Esto imprimirá en tu terminal lo que la IA realmente está "viendo"
            print(f"\n--- [DEBUG VISTA IA] Primeros 500 caracteres leídos: ---\n{full_text_debug[:500]}\n----------------------------------------------------\n")
            
            return docs

        except Exception as e:
            print(f"Error processing PDF with pdfplumber: {e}")
            return []