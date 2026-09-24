from supabase import create_client, Client
from app.core.config import settings
from app.core.logger import logger


class SupabaseClient:
    _instance: Client | None = None
    
    @classmethod
    def get_client(cls) -> Client:
        if cls._instance is None:
            logger.info("Initializing Supabase client")
            cls._instance = create_client(
                supabase_url=settings.supabase_url,
                supabase_key=settings.supabase_key
            )
        return cls._instance
    
    @classmethod
    async def health_check(cls) -> bool:
        try:
            client = cls.get_client()
            response = client.table("knowledge_chunks").select("id").limit(1).execute()
            logger.info("Supabase health check passed")
            return True
        except Exception as e:
            logger.error(f"Supabase health check failed: {e}")
            return False
    
    @classmethod
    async def match_knowledge_chunks(
        cls,
        query_embedding: list[float],
        match_threshold: float = 0.7,
        match_count: int = 5,
        filter_category: str | None = None
    ) -> list[dict]:
        try:
            client = cls.get_client()
            
            params = {
                "query_embedding": query_embedding,
                "match_threshold": match_threshold,
                "match_count": match_count,
                "filter_category": filter_category
            }
            
            response = client.rpc("match_knowledge_chunks", params).execute()
            logger.info(f"Retrieved {len(response.data)} knowledge chunks")
            return response.data
        except Exception as e:
            logger.error(f"Error matching knowledge chunks: {e}")
            return []


def get_supabase() -> Client:
    return SupabaseClient.get_client()
