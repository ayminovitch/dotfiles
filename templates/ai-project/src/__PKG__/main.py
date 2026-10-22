"""HTTP entry point."""

import logging

from fastapi import FastAPI

from __PKG__ import __version__
from __PKG__.config import get_settings

settings = get_settings()
logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name, version=__version__)


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness check used by Docker, load balancers and CI."""
    return {"status": "ok", "environment": settings.environment, "version": __version__}
