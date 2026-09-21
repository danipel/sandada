from pydantic import BaseModel, Field


class AnalysisRequest(BaseModel):
    barcode: str = Field(
        ...,
        min_length=8,
        max_length=14,
        description="Código EAN o UPC del producto"
    )
    user_query: str | None = Field(
        default=None,
        description="Pregunta contextual del usuario"
    )
    user_restrictions: list[str] = Field(
        default_factory=list,
        description="Restricciones del usuario (ej: ['diabetico', 'celiaco'])"
    )


class HealthCheckResponse(BaseModel):
    status: str
    service: str
    supabase_connected: bool
    version: str = "1.0.0"
