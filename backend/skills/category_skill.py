from core.ollama_client import OllamaClient

YOUTUBE_CATEGORIES = {
    1: "Film & Animation", 2: "Autos & Vehicles", 10: "Music",
    15: "Pets & Animals", 17: "Sports", 19: "Travel & Events",
    20: "Gaming", 21: "Videoblogging", 22: "People & Blogs",
    23: "Comedy", 24: "Entertainment", 25: "News & Politics",
    26: "Howto & Style", 27: "Education", 28: "Science & Technology",
    29: "Nonprofits & Activism",
}


class CategorySkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        cats = "\n".join([f"{k}: {v}" for k, v in YOUTUBE_CATEGORIES.items()])
        default = brand.get("category_default", 22)

        system = "You classify YouTube videos into the correct category. Respond with ONLY a number."
        prompt = f"""Title: {title}
Context: {context}

Available YouTube categories:
{cats}

Output ONLY the category ID number:"""

        model = self.ollama.get_model("category")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.1)
        try:
            digits = "".join(c for c in response if c.isdigit())[:2]
            cat_id = int(digits) if digits else default
            if cat_id not in YOUTUBE_CATEGORIES:
                cat_id = default
        except Exception:
            cat_id = default

        return {
            "category_id": cat_id,
            "category_name": YOUTUBE_CATEGORIES[cat_id],
        }