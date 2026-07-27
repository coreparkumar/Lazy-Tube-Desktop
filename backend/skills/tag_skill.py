from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class TagSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)

        system = "You generate YouTube tags for maximum discoverability."
        prompt = f"""Channel: {brand.get('channel', {}).get('name', '')}
Brand context:
{brand_ctx}

Title: {title}
Context: {context}

Generate 20-25 YouTube tags:
- Mix of broad (1-2 words) and long-tail (3-5 words)
- Include variations: singular/plural, with/without year
- Include common related searches people would type
- Lowercase, comma-separated, NO # symbol

Output ONLY the comma-separated tags:"""

        model = self.ollama.get_model("tags")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.5)
        text = response.replace("\n", ",")
        tags = [t.strip().lstrip("#").strip()
                for t in text.split(",") if t.strip()]
        return {"tags": tags[:30]}