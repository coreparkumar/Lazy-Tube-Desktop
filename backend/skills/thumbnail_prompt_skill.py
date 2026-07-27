from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class ThumbnailPromptSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict,
                 ref_thumbnails: list = None) -> dict:
        brand_ctx = build_brand_context(brand)
        vis = brand.get("visual_brand", {})

        ref_section = ""
        if ref_thumbnails:
            ref_section = "\nReference style from your recent successful thumbnails:\n" + \
                "\n".join([f"- {r.get('title', '')}" for r in ref_thumbnails[:3]]) + \
                "\nMatch this visual style.\n"

        system = """You are an expert YouTube thumbnail designer. You create prompts optimized for Google Nano Banana (Gemini 2.5 Flash Image). Your prompts are vivid, specific, and produce scroll-stopping 16:9 images."""

        prompt = f"""Channel brand:
{brand_ctx}

Visual brand:
- Primary color: {vis.get("primary_color", "cyan")}
- Secondary: {vis.get("secondary_color", "dark blue")}
- Mood: {vis.get("mood", "modern")}
- Text font: {vis.get("font_title", "bold sans-serif")}

Video title: {title}
Context: {context}
{ref_section}

Generate 3 thumbnail concepts as image prompts for Google Nano Banana.

For each concept output EXACTLY this format:

Concept [number]:
Prompt: [vivid cinematic 16:9 image prompt, no text in image, photorealistic, 8K detail]
TextOverlay: [3-5 words ALL CAPS for headline text]
Composition: [where elements are placed]
Mood: [emotion/feeling]
Colors: [3 hex colors]

Concept 1:
Prompt:"""

        model = self.ollama.get_model("thumbnail")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.9)
        return {
            "raw_response": response,
            "prompts": self._parse_concepts(response),
        }

    def _parse_concepts(self, text: str) -> list:
        concepts = []
        blocks = text.split("Concept ")
        for block in blocks[1:]:
            concept = {"text_overlay": "", "prompt": "",
                       "composition": "", "mood": "", "colors": ""}
            current = "prompt"
            for line in block.split("\n"):
                line = line.strip()
                low = line.lower()
                if low.startswith("prompt:"):
                    current = "prompt"
                    concept["prompt"] = line.split(":", 1)[1].strip()
                elif low.startswith("textoverlay:") or low.startswith("text overlay:"):
                    current = "text_overlay"
                    concept["text_overlay"] = line.split(":", 1)[1].strip()
                elif low.startswith("composition:"):
                    current = "composition"
                    concept["composition"] = line.split(":", 1)[1].strip()
                elif low.startswith("mood:"):
                    current = "mood"
                    concept["mood"] = line.split(":", 1)[1].strip()
                elif low.startswith("colors:"):
                    current = "colors"
                    concept["colors"] = line.split(":", 1)[1].strip()
                elif line and not line[0].isdigit():
                    if current and concept.get(current) is not None:
                        concept[current] = (concept[current] + " " + line).strip()
            if concept["prompt"] and len(concept["prompt"]) > 10:
                concepts.append(concept)
        return concepts[:3]