from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
import sys
import threading
import webbrowser

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(BACKEND_DIR)

for path in (BACKEND_DIR, ROOT_DIR):
    if path and path not in sys.path:
        sys.path.insert(0, path)

if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
    for path in (sys._MEIPASS, os.path.join(sys._MEIPASS, "backend")):
        if path and path not in sys.path:
            sys.path.insert(0, path)

try:
    from backend.api.generate import router as generate_router
    from backend.api.review import router as review_router
    from backend.api.upload import router as upload_router
    from backend.api.youtube_helpers import router as youtube_router
    from backend.api.settings import router as settings_router
except ModuleNotFoundError:
    from api.generate import router as generate_router
    from api.review import router as review_router
    from api.upload import router as upload_router
    from api.youtube_helpers import router as youtube_router
    from api.settings import router as settings_router

app = FastAPI(title="lazy-tube", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(generate_router, prefix="/api")
app.include_router(review_router, prefix="/api")
app.include_router(upload_router, prefix="/api")
app.include_router(youtube_router, prefix="/api")
app.include_router(settings_router, prefix="/api")

if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
    frontend_dist = os.path.join(sys._MEIPASS, "frontend", "dist")
else:
    frontend_dist = os.path.join(ROOT_DIR, "frontend", "dist")

if os.path.exists(frontend_dist):
    if os.path.exists(os.path.join(frontend_dist, "assets")):
        app.mount("/assets", StaticFiles(directory=os.path.join(frontend_dist, "assets")), name="assets")

    @app.get("/{full_path:path}")
    async def serve_frontend(full_path: str):
        file_path = os.path.join(frontend_dist, full_path)
        if os.path.exists(file_path) and os.path.isfile(file_path):
            return FileResponse(file_path)
        return FileResponse(os.path.join(frontend_dist, "index.html"))

if __name__ == "__main__":
    import uvicorn

    if getattr(sys, "frozen", False):
        threading.Timer(1.5, lambda: webbrowser.open("http://127.0.0.1:8000")).start()

    uvicorn.run(app, host="127.0.0.1", port=8000, reload=False)