from pydantic import BaseModel, Field


class AnalysisRequest(BaseModel):
    barcode: str = Field(..., min_length=8, max_length=14, description="Código EAN o UPC")
    user_query: str | None = Field(default=None, description="Pregunta contextual del usuario")
    user_profile: dict | None = Field(default=None, description="Perfil del usuario (condiciones, alergias, preferencias)")


class IngestRequest(BaseModel):
    url: str = Field(..., description="URL del documento a procesar")
    category: str = Field(..., description="Categoría del contenido (Diabetes, Keto, Allergies, etc.)")
    title: str | None = Field(default=None, description="Título personalizado del documento")


class HealthCheckResponse(BaseModel):
    status: str
    service: str
    supabase_connected: bool
    version: str = "1.0.0"


class AnalysisResponse(BaseModel):
    barcode: str
    product: dict
    analysis: str
    sources_count: int
    user_query: str | None
