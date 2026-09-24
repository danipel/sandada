from fastapi import APIRouter, HTTPException
from app.schemas.requests import AnalysisRequest, AnalysisResponse
from app.services.rag_engine import RAGEngine
from app.core.logger import logger

router = APIRouter()


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_product(request: AnalysisRequest):
    try:
        logger.info(f"Analyzing product with barcode: {request.barcode}")
        
        result = await RAGEngine.analyze_product(
            barcode=request.barcode,
            user_query=request.user_query,
            user_profile=request.user_profile
        )
        
        if "error" in result:
            raise HTTPException(status_code=404, detail=result["error"])
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in analyze endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
