import google.generativeai as genai
from app.core.config import settings
from app.core.logger import logger
from app.services.embeddings import EmbeddingService
from app.db.supabase_client import SupabaseClient


class RAGEngine:
    _configured = False
    
    @classmethod
    def _ensure_configured(cls):
        if not cls._configured:
            genai.configure(api_key=settings.gemini_api_key)
            cls._configured = True
            logger.info("Gemini API configured for RAG")
    
    @classmethod
    async def analyze_product(
        cls,
        barcode: str,
        user_query: str | None = None,
        user_profile: dict | None = None
    ) -> dict:
        cls._ensure_configured()
        
        try:
            supabase = SupabaseClient.get_client()
            
            product_response = supabase.table("products").select("*").eq("barcode", barcode).execute()
            
            if not product_response.data:
                return {
                    "error": "Product not found",
                    "barcode": barcode
                }
            
            product = product_response.data[0]
            
            context_query = user_query or f"Analizar producto: {product.get('product_name', 'Sin nombre')}"
            
            query_embedding = await EmbeddingService.generate_query_embedding(context_query)
            
            knowledge_chunks = await SupabaseClient.match_knowledge_chunks(
                query_embedding=query_embedding,
                match_threshold=0.7,
                match_count=5,
                filter_category=None
            )
            
            prompt = cls._build_analysis_prompt(product, knowledge_chunks, user_query, user_profile)
            
            model = genai.GenerativeModel("gemini-1.5-flash")
            response = model.generate_content(prompt)
            
            logger.info(f"Generated analysis for barcode {barcode}")
            
            return {
                "barcode": barcode,
                "product": product,
                "analysis": response.text,
                "sources_count": len(knowledge_chunks),
                "user_query": user_query
            }
            
        except Exception as e:
            logger.error(f"Error in RAG analysis: {e}")
            raise
    
    @classmethod
    def _build_analysis_prompt(
        cls,
        product: dict,
        knowledge_chunks: list[dict],
        user_query: str | None,
        user_profile: dict | None
    ) -> str:
        prompt_parts = [
            "Eres un asistente nutricional experto. Analiza el siguiente producto y proporciona recomendaciones basadas en la evidencia científica disponible.\n"
        ]
        
        prompt_parts.append("## PRODUCTO\n")
        prompt_parts.append(f"- Nombre: {product.get('product_name', 'N/A')}\n")
        prompt_parts.append(f"- Marca: {product.get('brands', 'N/A')}\n")
        prompt_parts.append(f"- Código de barras: {product.get('barcode', 'N/A')}\n")
        
        if product.get('ingredients_text'):
            prompt_parts.append(f"- Ingredientes: {product['ingredients_text']}\n")
        
        if product.get('nutriments'):
            prompt_parts.append("\n### Información Nutricional (por 100g):\n")
            nutriments = product['nutriments']
            for key, value in nutriments.items():
                prompt_parts.append(f"- {key}: {value}\n")
        
        if knowledge_chunks:
            prompt_parts.append("\n## CONTEXTO CIENTÍFICO Y NUTRICIONAL\n")
            for i, chunk in enumerate(knowledge_chunks, 1):
                prompt_parts.append(f"\n### Fuente {i} (Similitud: {chunk.get('similarity', 0):.2f})\n")
                prompt_parts.append(f"{chunk.get('chunk_text', '')}\n")
        
        if user_profile:
            prompt_parts.append("\n## PERFIL DEL USUARIO\n")
            if user_profile.get('conditions'):
                prompt_parts.append(f"- Condiciones de salud: {', '.join(user_profile['conditions'])}\n")
            if user_profile.get('dietary_preferences'):
                prompt_parts.append(f"- Preferencias dietéticas: {', '.join(user_profile['dietary_preferences'])}\n")
            if user_profile.get('allergies'):
                prompt_parts.append(f"- Alergias: {', '.join(user_profile['allergies'])}\n")
        
        if user_query:
            prompt_parts.append(f"\n## PREGUNTA DEL USUARIO\n{user_query}\n")
        
        prompt_parts.append("\n## INSTRUCCIONES\n")
        prompt_parts.append("1. Proporciona un análisis objetivo del producto basado ÚNICAMENTE en la información proporcionada\n")
        prompt_parts.append("2. Resalta ingredientes o componentes nutricionales relevantes para la salud\n")
        prompt_parts.append("3. Si el usuario tiene condiciones específicas, evalúa la idoneidad del producto\n")
        prompt_parts.append("4. Proporciona recomendaciones claras y accionables\n")
        prompt_parts.append("5. NO inventes información que no esté en el contexto\n")
        prompt_parts.append("6. Si no tienes suficiente información para responder algo, indícalo claramente\n")
        prompt_parts.append("7. Usa un tono empático pero profesional\n")
        
        return "".join(prompt_parts)
