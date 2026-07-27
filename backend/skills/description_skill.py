from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class DescriptionSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)
        template = brand.get("description_template", "")
        hashtags = brand.get("hashtags_fixed", [])
        about = brand.get("channel", {}).get("about", "")

        system = "You write YouTube descriptions that are engaging, SEO-friendly, and match the channel voice exactly."
        prompt = f"""Channel brand:
{brand_ctx}

Title: {title}
Video context: {context}

Template to follow:
{template if template else "Hook (2 lines) | Summary with bullets | Timestamps placeholder | Links | About | Hashtags"}

About this channel: {about}
Fixed channel hashtag: #{hashtags[0] if hashtags else 'channel'}

Write a complete YouTube description:
- First 2 lines = hook (visible above "show more")
- Then summary with 3-5 bullet points
- Add timestamp placeholder line: "0:00 Intro" etc.
- Brief about-channel blurb (1-2 lines)
- 3-5 relevant hashtags at the end (include the fixed channel hashtag)

Output ONLY the description, in markdown:"""

        model = self.ollama.get_model("description")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.7)
        return {"description": response.strip()}