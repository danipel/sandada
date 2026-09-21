-- =====================================================
-- Migración Inicial: RAG Nutricional
-- Fecha: 2026-09-20
-- Descripción: Setup inicial para el sistema RAG con
--              tablas de conocimiento y productos
-- =====================================================

-- 1. Habilitar extensión pgvector (ya está habilitada pero lo verificamos)
CREATE EXTENSION IF NOT EXISTS vector;

-- =====================================================
-- 2. HABILITAR RLS EN TABLAS EXISTENTES
-- =====================================================
-- CRÍTICO: Estas tablas están expuestas sin RLS
-- Se habilita RLS pero sin policies por ahora (bloquea acceso anon)
-- El desarrollador debe crear policies específicas según su lógica de negocio

ALTER TABLE IF EXISTS "public"."spatial_ref_sys" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."subscription_plans" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."user_subscriptions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."groups" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."group_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."group_invitations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."payments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."goals" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."diet_types" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."user_goals" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."tags" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."diet_tag_rules" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."product_tags" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."product_ingredients" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."nutritional_info" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."markets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."locations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."price_history" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."current_prices" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."user_favorites" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."user_pantry_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."recipes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."recipe_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."recipe_feedback" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."product_embeddings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."knowledge_sources" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."knowledge_chunks" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."health_conditions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."health_condition_tag_rules" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."user_health_conditions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "public"."user_tag_restrictions" ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREAR TABLA DE CONOCIMIENTO NUTRICIONAL (RAG)
-- =====================================================
CREATE TABLE IF NOT EXISTS conocimiento_nutricional (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo TEXT NOT NULL,
    contenido TEXT NOT NULL,
    categoria TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    fuente_url TEXT,
    embedding VECTOR(768),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS en la nueva tabla
ALTER TABLE "public"."conocimiento_nutricional" ENABLE ROW LEVEL SECURITY;

-- Índice HNSW para búsqueda vectorial eficiente
CREATE INDEX IF NOT EXISTS idx_conocimiento_embedding_hnsw 
ON conocimiento_nutricional 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Índice para búsqueda por categoría
CREATE INDEX IF NOT EXISTS idx_conocimiento_categoria 
ON conocimiento_nutricional(categoria);

-- Índice para ordenar por fecha
CREATE INDEX IF NOT EXISTS idx_conocimiento_created_at 
ON conocimiento_nutricional(created_at DESC);

-- =====================================================
-- 4. FUNCIÓN RPC PARA BÚSQUEDA VECTORIAL
-- =====================================================
CREATE OR REPLACE FUNCTION match_conocimiento(
    query_embedding VECTOR(768),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    titulo TEXT,
    contenido TEXT,
    categoria TEXT,
    metadata JSONB,
    fuente_url TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cn.id,
        cn.titulo,
        cn.contenido,
        cn.categoria,
        cn.metadata,
        cn.fuente_url,
        1 - (cn.embedding <=> query_embedding) AS similarity
    FROM conocimiento_nutricional cn
    WHERE 1 - (cn.embedding <=> query_embedding) > match_threshold
    ORDER BY cn.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- =====================================================
-- 5. TRIGGER PARA ACTUALIZAR updated_at
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_conocimiento_nutricional_updated_at
    BEFORE UPDATE ON conocimiento_nutricional
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. COMENTARIOS PARA DOCUMENTACIÓN
-- =====================================================
COMMENT ON TABLE conocimiento_nutricional IS 
'Almacena conocimiento nutricional vectorizado para el sistema RAG: guías médicas, artículos de salud, información sobre aditivos, etc.';

COMMENT ON COLUMN conocimiento_nutricional.embedding IS 
'Vector de 768 dimensiones generado por Gemini text-embedding-004';

COMMENT ON COLUMN conocimiento_nutricional.categoria IS 
'Categoría del conocimiento: Diabetes, Keto, Aditivos, Ingredientes, etc.';

COMMENT ON COLUMN conocimiento_nutricional.metadata IS 
'Metadata flexible en formato JSON: autor, fecha_publicacion, tags, etc.';

COMMENT ON FUNCTION match_conocimiento IS 
'Función de búsqueda por similitud coseno para recuperación RAG. Retorna chunks más relevantes según el embedding de la consulta.';
