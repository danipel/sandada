from fastapi import FastAPI
from app.core.config import settings
from app.core.logger import logger
from app.api.routes import health, rag

app = FastAPI(
    title=settings.project_name,
    version="1.0.0",
    docs_url=f"{settings.api_v1_prefix}/docs",
    openapi_url=f"{settings.api_v1_prefix}/openapi.json"
)

app.include_router(
    health.router,
    prefix=settings.api_v1_prefix,
    tags=["health"]
)

app.include_router(
    rag.router,
    prefix=settings.api_v1_prefix,
    tags=["rag"]
)


@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.project_name} - Environment: {settings.environment}")


@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"Shutting down {settings.project_name}")
