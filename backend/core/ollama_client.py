import httpx
import yaml
import os
import sys
from pathlib import Path
from typing import Optional


def get_base_dir() -> Path:
    """
    Returns the root directory where external configuration/data lives.
    If running as a PyInstaller bundle, returns the directory containing the executable.
    Otherwise, returns the project root directory.
    """
    if getattr(sys, 'frozen', False):
        # Running inside PyInstaller EXE -> dist/publish folder
        return Path(sys.executable).parent
    else:
        # Standard Python runtime -> project root folder
        return Path(__file__).resolve().parent.parent.parent


class OllamaClient:
    def __init__(self, config_path: str = None):
        if config_path is None:
            base_dir = get_base_dir()
            config_file = base_dir / "config" / "ollama_config.yaml"
            
            # Fallback check if the config file is bundled inside sys._MEIPASS
            if not config_file.exists() and getattr(sys, '_MEIPASS', False):
                config_file = Path(sys._MEIPASS) / "config" / "ollama_config.yaml"
                
            config_path = str(config_file)

        if not os.path.exists(config_path):
            raise FileNotFoundError(
                f"Ollama config not found at '{config_path}'. Make sure config/ollama_config.yaml exists."
            )

        with open(config_path, "r", encoding="utf-8") as f:
            self.config = yaml.safe_load(f)["ollama"]
            
        self.base_url = self.config["base_url"]
        self.models = self.config["models"]

    def get_model(self, task: str) -> str:
        assignment = self.config.get("assignment", {})
        return assignment.get(task, self.models["balanced"])

    def generate(self, prompt: str, model: Optional[str] = None,
                 temperature: float = 0.7, system: Optional[str] = None) -> str:
        requested_model = model or self.models["balanced"]
        fallback_models = []
        for candidate in [requested_model, self.models.get("balanced"), self.models.get("fast"), self.models.get("quality")]:
            if candidate and candidate not in fallback_models:
                fallback_models.append(candidate)

        payload = {
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": temperature},
        }
        if system:
            payload["system"] = system

        last_error = None
        for candidate_model in fallback_models:
            payload["model"] = candidate_model
            try:
                with httpx.Client(timeout=180) as client:
                    r = client.post(f"{self.base_url}/api/generate", json=payload)
                    if r.status_code == 404:
                        last_error = r.text
                        continue
                    r.raise_for_status()
                    return r.json()["response"].strip()
            except Exception as e:
                last_error = str(e)

        return f"[ERROR calling Ollama: {last_error}]"

    def chat(self, messages: list, model: Optional[str] = None) -> str:
        model = model or self.models["balanced"]
        payload = {"model": model, "messages": messages, "stream": False}
        try:
            with httpx.Client(timeout=180) as client:
                r = client.post(f"{self.base_url}/api/chat", json=payload)
                r.raise_for_status()
                return r.json()["message"]["content"].strip()
        except Exception as e:
            return f"[ERROR calling Ollama: {e}]"