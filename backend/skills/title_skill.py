from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class TitleSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)
        style = brand.get("title_style", {})
        pattern = style.get("pattern", "{topic}: {hook}")
        examples = ", ".join(style.get("examples", [])) or "N/A"

        system = "You are an expert YouTube title creator. Output ONLY the titles, one per line. No numbering, no commentary."
        prompt = f"""Channel brand:
{brand_ctx}

Title pattern to follow: {pattern}
Reference examples: {examples}

Generate 5 title options for this video:
{context}

Rules:
- Under 100 characters each
- Include primary keyword from the topic
- Mix styles: curiosity, how-to, listicle, news
- No clickbait, no misleading claims
- Match the channel tone exactly

Output 5 titles, one per line:"""

        model = self.ollama.get_model("title")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.8)
        titles = []
        for line in response.split("\n"):
            t = line.strip().lstrip("0123456789.-) ").strip()
            if t and len(t) > 5:
                titles.append(t[:100])
        return {"titles": titles[:5], "selected": titles[0] if titles else ""}