# AGENTS.MD — Contexto del Sistema RAG Nutricional

Este documento define la arquitectura, las responsabilidades de los agentes y los estándares de desarrollo para el asistente de toma de decisiones nutricionales en supermercados.

---

## 1. Visión General del Proyecto

Sistema distribuido para recomendar y analizar alimentos en tiempo real mediante el escaneo de productos en supermercados. Combina búsqueda relacional estricta (metadatos de alimentos) con búsqueda semántica (guías de salud) mediante una arquitectura **Hybrid RAG**.

---

## 2. Stack Tecnológico & Roles

[ Usuario App ] ──> [ Go Gateway ] ──> [ Python / FastAPI ] ──> [ Supabase (PostgreSQL + pgvector) ]
│
└──> [ Gemini API ]


| Componente | Tecnología | Responsabilidad Principal |
| :--- | :--- | :--- |
| **API Gateway** | Go | Autenticación, Rate Limiting, Enrutamiento de bajo latencia y Proxy a microservicios. |
| **Microservicio RAG** | Python 3.11+ / FastAPI | Lógica del RAG, Ingesta/Chunking de datos, Orquestación del LLM y Endpoints de recomendación. |
| **Base de Datos** | Supabase (PostgreSQL) | Almacenamiento híbrido: Datos estructurados (`JSONB` para nutrición) y Vectores (`pgvector`). |
| **LLM / Embeddings** | Gemini 1.5 / `text-embedding-004` | Generación de embeddings semánticos y razonamiento contextual final para el usuario. |

---

## 3. Arquitectura de Datos (Supabase)

El sistema utiliza **Búsqueda Híbrida**: no todos los datos se vectorizan.

1. **`products` (Hard Data):** Search by `barcode` (EAN) or exact filters (`sugar_total_g < 5`). No embeddings.
2. **`knowledge_sources` + `knowledge_chunks` (Semantic RAG):** Medical guides, intolerances, health articles, harmful ingredients. Stored with 768-dimensional vectors (Gemini text-embedding-004).

### Simplified Schema

```sql
-- Required vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Knowledge Sources (Documents)
CREATE TABLE knowledge_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR NOT NULL,
    source_url TEXT,
    type VARCHAR, -- "article", "guide", "study"
    category VARCHAR(100), -- "Diabetes", "Keto", "Additives"
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Knowledge Chunks (RAG Vectorized Chunks)
CREATE TABLE knowledge_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES knowledge_sources(id),
    chunk_text TEXT NOT NULL,
    embedding VECTOR(768), -- Gemini embeddings
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products (Existing table in DB)
-- Barcode-based lookup, structured nutritional data
```
## 4. Flujo de Trabajo del RAG (Pipeline)

1. Recepción: El gateway en Go recibe la petición (barcode + pregunta opcional del usuario) y la deriva al microservicio FastAPI.

2. Obtención del Producto: FastAPI consulta la tabla productos por barcode (SQL indexado).

3. Búsqueda Vectorial: Se genera el embedding de la consulta del usuario mediante text-embedding-004 y se realiza una consulta por similitud coseno en conocimiento_nutricional.

4. Ensamblaje del Contexto: Se construye un prompt inyectando:

  - Ficha técnica del producto (Ingredientes, JSON nutricional).

  - Fragmentos más relevantes recuperados de Supabase.

  - Pregunta/Preferencia del usuario.

5. Inferencia: Gemini procesa la consulta estructurada y devuelve la respuesta en Markdown.

## 5. Reglas y Directrices para Agentes de IA / Devs
Al generar código para este repositorio, los asistentes deben cumplir con las siguientes directrices:

- Go Gateway:

  - Mantener el principio de responsabilidad única; no implementar lógica de negocio nutricional en el gateway.

  - Priorizar alto rendimiento (goroutines, manejo eficiente de HTTP client timeouts).

- Python / FastAPI (Microservicio RAG):

  - Utilizar tipos estrictos (Pydantic v2 y typing).

  - Utilizar llamadas asíncronas (async/await) para llamadas a APIs externas (Gemini y Supabase).

  - Desplegar pipelines de ingesta idempotentes (no duplicar vectores al procesar las mismas fuentes).

- Consultas Supabase / Pgvector:

  - Toda búsqueda vectorial debe limitar sus resultados (LIMIT 3 a 5) e incluir un umbral de similitud razonable (match_threshold > 0.7).

  - No realizar búsquedas semánticas para consultas que se resuelvan con un ID o código de barras estricto.

- Prompts de Gemini:

  - Diseñar prompts con un tono empático pero objetivamente médico/nutricional.

  - Exigir explicaciones basadas únicamente en el contexto proporcionado (evitar alucinaciones en recomendaciones de salud).

---

## 6. Desarrollo Local con Docker

### Requisitos Previos

- Docker y Docker Compose instalados
- Python 3.11+ (solo para desarrollo sin Docker)
- Credenciales de Supabase (`SUPABASE_URL`, `SUPABASE_KEY`)
- Google Gemini API Key

### Configuración Inicial

1. **Navegar al directorio del servicio RAG:**

```bash
cd RAG/rag-service
```

2. **Crear archivo `.env` desde el template:**

```bash
cp .env.example .env
```

3. **Editar `.env` con tus credenciales:**

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_KEY=tu-service-role-key
GEMINI_API_KEY=tu-gemini-api-key
LOG_LEVEL=INFO
ENVIRONMENT=development
```

### Iniciar el Servicio

**Con Docker (Recomendado):**

```bash
docker-compose up --build
```

**Sin Docker:**

```bash
python -m venv venv
source venv/bin/activate  # Windows: .\venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

El servicio estará disponible en `http://localhost:8000`

### Verificar el Servicio

```bash
curl http://localhost:8000/api/v1/health
```

Respuesta esperada:
```json
{
  "status": "healthy",
  "service": "RAG Nutricional",
  "supabase_connected": true,
  "version": "1.0.0"
}
```

### Documentación de la API

Una vez iniciado el servicio, la documentación interactiva está disponible en:

- **Swagger UI:** `http://localhost:8000/api/v1/docs`
- **ReDoc:** `http://localhost:8000/api/v1/redoc`

### Detener el Servicio

```bash
docker-compose down
```

Para detener y eliminar volúmenes:

```bash
docker-compose down -v
```

---

## 7. Estructura del Proyecto

```
RAG/
├── rag-service/
│   ├── app/
│   │   ├── api/          # Endpoints FastAPI
│   │   ├── core/         # Configuración y logging
│   │   ├── db/           # Clientes de Supabase
│   │   ├── schemas/      # Modelos Pydantic
│   │   └── services/     # Lógica RAG (próximamente)
│   ├── tests/            # Pruebas
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── requirements.txt
├── migrations/
│   └── 001_initial_schema.sql
└── source_links.md       # Fuentes para ingesta
```

---

## 8. Próximos Pasos

1. **Implementar módulo de embeddings** (`app/services/embeddings.py`)
2. **Implementar scraper y chunker** para procesar `source_links.md`
3. **Crear endpoint de ingesta** (`POST /api/v1/ingest`)
4. **Implementar motor RAG** (`app/services/rag_engine.py`)
5. **Crear endpoint de análisis** (`POST /api/v1/analyze`)