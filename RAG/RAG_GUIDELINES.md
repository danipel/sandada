# RAG_GUIDELINES.MD — Especificación Técnica del Engine RAG

Este documento detalla la arquitectura interna, las reglas de desarrollo y el funcionamiento del microservicio de Retrieval-Augmented Generation (RAG) construido con **Python 3.11+**, **FastAPI**, **Supabase (pgvector)** y **Google Gemini**.

---

## 1. Responsabilidades del Módulo RAG

El microservicio RAG es responsable exclusivamente de:
1. **Ingesta y Procesamiento de Datos:** Convertir PDFs, enlaces y documentos nutricionales en chunks vectorizados.
2. **Recuperación Híbrida (Retrieval):** Combinar datos estructurados (SQL exacto por código de barras) con datos no estructurados (búsqueda vectorial por similitud).
3. **Generación Aumentada:** Inyectar el contexto recuperado en **Gemini** para producir respuestas precisas sobre decisiones alimentarias.

---

## 2. Estructura del Proyecto

```text
rag-service/
├── app/
│   ├── api/                # Endpoints de FastAPI (v1)
│   │   └── routes/         # Router para /query, /ingest, /products
│   ├── core/               # Configuración (Pydantic Settings, Loggers)
│   ├── db/                 # Clientes de Supabase y funciones pgvector
│   ├── services/
│   │   ├── scraper.py      # Extracción de contenido web/PDFs
│   │   ├── chunker.py      # Estrategias de división de texto
│   │   ├── embeddings.py   # Wrapper para Gemini text-embedding-004
│   │   └── rag_engine.py   # Orquestador del flujo RAG + Gemini 1.5 Pro/Flash
│   └── schemas/            # Modelos Pydantic (requests, responses, metadata)
├── tests/                  # Pruebas unitarias e integración de embeddings
├── main.py                 # Punto de entrada de la aplicación FastAPI
└── requirements.txt

```

---

## 3. Pipeline de Ingesta (ETL Pipeline)

Para procesar artículos de salud, guías nutricionales o páginas web, la ingesta debe seguir este ciclo riguroso:

```text
[ Enlace / HTML / PDF ]
          │
          ▼
   1. Extracción (Clean HTML -> Markdown) via Trafilatura / BeautifulSoup
          │
          ▼
   2. Chunking (RecursiveCharacterTextSplitter: 800 tokens, 100 overlap)
          │
          ▼
   3. Embedding Generation (Gemini `text-embedding-004` - 768 dims)
          │
          ▼
   4. Almacenamiento (Supabase: `conocimiento_nutricional` + metadata)

```

### Reglas de Ingesta

* **Limpieza previa:** Nunca vectorizar HTML con etiquetas (scripts, navbars, footers). Solo texto plano o Markdown.
* **Metadata obligatoria:** Cada chunk debe almacenarse con metadatos claros (`fuente_url`, `categoria`, `titulo_articulo`, `fecha_procesamiento`).
* **Idempotencia:** Evitar re-insertar el mismo documento. Verificar por hash del contenido o URL de origen.

---

## 4. Pipeline de Búsqueda y Generación (Retrieval & Ingest)

Cuando se consulta por un producto (`/api/v1/analyze`):

1. **Get Product Data (SQL):** Se consulta la tabla `productos` mediante el código de barras (`barcode`).
2. **Semantic Search (pgvector):** Se genera el embedding de la pregunta o preferencia del usuario y se ejecuta la RPC de Supabase `match_conocimiento()` usando similitud coseno (`<=>`).
3. **Prompt Framing:** Se construye el prompt estricto previendo alucinaciones:

```python
SYSTEM_INSTRUCTION = """
Eres un especialista en nutrición evaluando productos de supermercado.
Tu objetivo es dar recomendaciones objetivas basadas ÚNICAMENTE en la ficha técnica del producto
y la evidencia/guías de salud recuperadas.

Reglas:
- Si el contexto no responde la pregunta, indica que no cuentas con suficiente evidencia.
- No inventes ingredientes ni propiedades nutricionales.
- Estructura tu respuesta en Markdown: Resumen, Pros, Contras y Veredicto.
"""

```

---

## 5. Estándares de Código para Agentes e Ingenieros

Cualquier código escrito en este módulo debe seguir las siguientes reglas:

### A. Tipado Estricto y Async

* Toda función de E/S (Supabase, API Gemini, HTTP Scraping) debe ser **asíncrona (`async def`)**.
* Usar `Pydantic` v2 para validar las entradas del usuario y la salida de la API.

```python
# Ejemplo de esquema para respuestas de análisis
from pydantic import BaseModel, Field

class AnalysisRequest(BaseModel):
    barcode: str = Field(..., min_length=8, max_length=14, description="Código EAN o UPC")
    user_query: str | None = Field(default=None, description="Pregunta contextual del usuario")
    user_restrictions: list[str] = Field(default_factory=list, description="ej: ['diabetico', 'celiaco']")

```

### B. Cliente de Gemini y Embeddings

* Utilizar la librería oficial `google-genai`.
* Para embeddings usar `text-embedding-004` (dimensión fija **768**).
* Para generación preferir `gemini-1.5-flash` por menor latencia en el supermercado, escalando a `gemini-1.5-pro` solo si la consulta requiere razonamiento complejo.

### C. Manejo de Excepciones

* Las fallas al conectar con la API de Gemini o Supabase no deben tirar el servidor. Usar bloques `try/except` refinados y fallbacks apropiados.

---

## 6. Pruebas y Validación del RAG

* **Pruebas de Embeddings:** Validar que la consulta `"azúcar para diabéticos"` devuelva chunks etiquetados bajo la categoría `diabetes` o `indice_glucemico` con `similarity > 0.70`.
* **Pruebas Integradas:** Probar el endpoint pasando un `barcode` existente + un perfil sintético (ej: "Apto para keto") y verificar que la respuesta de Gemini responda directamente si el producto cumple o no.

```
