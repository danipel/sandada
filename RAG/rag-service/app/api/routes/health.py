from fastapi import APIRouter
from app.schemas.requests import HealthCheckResponse
from app.db.supabase_client import SupabaseClient

router = APIRouter()


@router.get("/health", response_model=HealthCheckResponse)
async def health_check():
    supabase_ok = await SupabaseClient.health_check()
    
    return HealthCheckResponse(
        status="healthy" if supabase_ok else "degraded",
        service="RAG Nutricional",
        supabase_connected=supabase_ok
    )
