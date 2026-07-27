from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class HashtagSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)
        fixed = brand.get("hashtags_fixed", [])

        system = "You create YouTube hashtags."
        prompt = f"""Channel brand:
{brand_ctx}

Title: {title}
Context: {context}

Generate exactly 3 hashtags specific to THIS video topic.
Output WITHOUT the # symbol, one per line, no numbering:"""

        model = self.ollama.get_model("hashtag")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.6)
        tags = [t.strip().replace("#", "").strip()
                for t in response.split("\n") if t.strip()]
        tags = tags[:3]
        all_tags = [f"#{t}" for t in fixed] + [f"#{t}" for t in tags]
        return {"hashtags": all_tags}