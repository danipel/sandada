-- =====================================================
-- Migration: Adapt existing knowledge tables for RAG
-- Date: 2026-09-24
-- Description: Modify knowledge_sources and knowledge_chunks
--              to support Gemini embeddings (768 dims) and
--              add category/metadata support
-- =====================================================

-- 1. Add missing columns to knowledge_sources
ALTER TABLE knowledge_sources
ADD COLUMN IF NOT EXISTS category VARCHAR(100),
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 2. Add metadata column to knowledge_chunks
ALTER TABLE knowledge_chunks
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. Drop old HNSW index (1536 dims for OpenAI)
DROP INDEX IF EXISTS idx_knowledge_chunks_embedding;

-- 4. Alter embedding column to 768 dimensions (Gemini)
-- Note: This will fail if there's existing data with 1536 dims
-- In that case, you need to migrate data first or drop and recreate
ALTER TABLE knowledge_chunks
ALTER COLUMN embedding TYPE VECTOR(768);

-- 5. Create new HNSW index for 768-dimensional embeddings
CREATE INDEX idx_knowledge_chunks_embedding_768 
ON knowledge_chunks 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- 6. Create index on category for filtering
CREATE INDEX IF NOT EXISTS idx_knowledge_sources_category 
ON knowledge_sources(category) 
WHERE category IS NOT NULL;

-- 7. Create trigger for updated_at on knowledge_sources
CREATE TRIGGER update_knowledge_sources_updated_at
    BEFORE UPDATE ON knowledge_sources
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 8. Create trigger for updated_at on knowledge_chunks
CREATE TRIGGER update_knowledge_chunks_updated_at
    BEFORE UPDATE ON knowledge_chunks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 9. Create RPC function for semantic search
CREATE OR REPLACE FUNCTION match_knowledge_chunks(
    query_embedding VECTOR(768),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 5,
    filter_category VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    chunk_id UUID,
    source_id UUID,
    source_title VARCHAR,
    source_url TEXT,
    source_category VARCHAR,
    chunk_text TEXT,
    chunk_metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kc.id AS chunk_id,
        kc.source_id,
        ks.title AS source_title,
        ks.source_url,
        ks.category AS source_category,
        kc.chunk_text,
        kc.metadata AS chunk_metadata,
        1 - (kc.embedding <=> query_embedding) AS similarity
    FROM knowledge_chunks kc
    LEFT JOIN knowledge_sources ks ON kc.source_id = ks.id
    WHERE 
        1 - (kc.embedding <=> query_embedding) > match_threshold
        AND (filter_category IS NULL OR ks.category = filter_category)
    ORDER BY kc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 10. Drop the old conocimiento_nutricional table and function
DROP TABLE IF EXISTS conocimiento_nutricional CASCADE;
DROP FUNCTION IF EXISTS match_conocimiento(VECTOR, FLOAT, INT);

-- 11. Add comments for documentation
COMMENT ON COLUMN knowledge_sources.category IS 
'Category of knowledge: Diabetes, Keto, Additives, Ingredients, etc.';

COMMENT ON COLUMN knowledge_sources.metadata IS 
'Flexible JSON metadata: author, publication_date, tags, etc.';

COMMENT ON COLUMN knowledge_chunks.metadata IS 
'Chunk-specific metadata: chunk_index, overlap_info, etc.';

COMMENT ON FUNCTION match_knowledge_chunks IS 
'Semantic search function using cosine similarity. Returns most relevant chunks with source information. Filter by category optional.';
