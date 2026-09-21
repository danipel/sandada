# RAG Nutricional

Microservicio de Retrieval-Augmented Generation para el sistema de decisiones nutricionales en supermercados.

## 🏗️ Estructura

```
rag-service/
├── app/
│   ├── api/          # Endpoints FastAPI
│   ├── core/         # Configuración y logging
│   ├── db/           # Clientes de base de datos
│   ├── schemas/      # Modelos Pydantic
│   └── services/     # Lógica RAG (embeddings, chunking, rag_engine)
├── tests/            # Pruebas
├── docker-compose.yml
├── Dockerfile
└── requirements.txt
```

## 📋 Requisitos

- Docker y Docker Compose
- Python 3.11+
- Project Supabase con RAG habilitado
- Google Gemini API Key

## 🚀 Inicio Rápido

### 1. Configurar Variables de Entorno

```bash
cp .env.example .env
```

Editar `.env` y completar:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_KEY=tu-anon-key
GEMINI_API_KEY=tu-api-key-de-gemini
LOG_LEVEL=INFO
ENVIRONMENT=development
```

### 2. Iniciar Servicio con Docker

```bash
cd rag-service
docker-compose up --build
```

El servicio estará disponible en `http://localhost:8000`

### 3. Verificar Estado

```bash
curl http://localhost:8000/api/v1/health
```

## 📚 Endpoints

### Health Check
```
GET /api/v1/health
```

### Análisis de Producto (PENDIENTE)
```
POST /api/v1/analyze
```

### Ingesta de Conocimiento (PENDIENTE)
```
POST /api/v1/ingest
```

## 🔧 Desarrollo Local (sin Docker)

```bash
python -m venv venv
source venv/bin/activate  # o .\venv\Scripts\activate en Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## 🗄️ Base de Datos

### Tabla `conocimiento_nutricional`

Almacena conocimiento vectorizado para RAG:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | Clave primaria |
| `titulo` | TEXT | Título del chunk |
| `contenido` | TEXT | Contenido textual |
| `categoria` | TEXT | Categoría (Diabetes, Keto, etc.) |
| `metadata` | JSONB | Metadatos adicionales |
| `fuente_url` | TEXT | Fuente original |
| `embedding` | VECTOR(768) | Embedding Gemini text-embedding-004 |
| `created_at` | TIMESTAMPTZ | Creación |
| `updated_at` | TIMESTAMPTZ | Actualización |

### Función `match_conocimiento()`

Búsqueda vectorial por similitud coseno:

```sql
SELECT * FROM match_conocimiento(
    query_embedding => '[...]',
    match_threshold => 0.7,
    match_count => 5
);
```

## 📝 Convenciones de Código

- Python 3.11+
- FastAPI con async/await
- Pydantic v2 para validación
- Tipado estricto
- Logging estructurado
- Exceptions handling robusto

## 📖 Más Info

Ver `AGENTS.md` y `RAG_GUIDELINES.md` en el root del proyecto.
