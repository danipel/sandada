import google.generativeai as genai
from app.core.config import settings
from app.core.logger import logger


class EmbeddingService:
    _configured = False
    
    @classmethod
    def _ensure_configured(cls):
        if not cls._configured:
            genai.configure(api_key=settings.gemini_api_key)
            cls._configured = True
            logger.info("Gemini API configured for embeddings")
    
    @classmethod
    async def generate_embedding(cls, text: str) -> list[float]:
        cls._ensure_configured()
        
        try:
            result = genai.embed_content(
                model="models/text-embedding-004",
                content=text,
                task_type="retrieval_document"
            )
            
            embedding = result['embedding']
            logger.debug(f"Generated embedding of dimension {len(embedding)}")
            return embedding
            
        except Exception as e:
            logger.error(f"Error generating embedding: {e}")
            raise
    
    @classmethod
    async def generate_query_embedding(cls, query: str) -> list[float]:
        cls._ensure_configured()
        
        try:
            result = genai.embed_content(
                model="models/text-embedding-004",
                content=query,
                task_type="retrieval_query"
            )
            
            embedding = result['embedding']
            logger.debug(f"Generated query embedding of dimension {len(embedding)}")
            return embedding
            
        except Exception as e:
            logger.error(f"Error generating query embedding: {e}")
            raise
    
    @classmethod
    async def generate_batch_embeddings(cls, texts: list[str]) -> list[list[float]]:
        cls._ensure_configured()
        
        embeddings = []
        for text in texts:
            try:
                embedding = await cls.generate_embedding(text)
                embeddings.append(embedding)
            except Exception as e:
                logger.error(f"Error in batch embedding for text: {text[:50]}... - {e}")
                embeddings.append([])
        
        logger.info(f"Generated {len(embeddings)} embeddings in batch")
        return embeddings
