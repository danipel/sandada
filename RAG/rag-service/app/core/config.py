from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )
    
    supabase_url: str
    supabase_key: str
    gemini_api_key: str
    
    log_level: str = "INFO"
    environment: str = "development"
    
    api_v1_prefix: str = "/api/v1"
    project_name: str = "RAG Nutricional"


settings = Settings()
