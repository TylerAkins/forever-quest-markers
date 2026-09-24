"""Rate-limited HTTP client with on-disk HTML cache."""

from __future__ import annotations

import hashlib
import time
import urllib.error
import urllib.request
from pathlib import Path

USER_AGENT = "ForeverQuestPins-WowheadDB/1.0 (+https://github.com; respectful scraper)"
DEFAULT_MIN_INTERVAL_S = 1.25


class WowheadClient:
    def __init__(
        self,
        cache_dir: Path,
        min_interval_s: float = DEFAULT_MIN_INTERVAL_S,
    ) -> None:
        self.cache_dir = cache_dir
        self.min_interval_s = min_interval_s
        self._last_fetch_at = 0.0
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:32]
        return self.cache_dir / f"{digest}.html"

    def get_html(self, url: str, *, force: bool = False) -> str:
        path = self._cache_path(url)
        if not force and path.is_file():
            return path.read_text(encoding="utf-8", errors="replace")

        self._throttle()
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            if exc.code == 429:
                time.sleep(30)
                return self.get_html(url, force=force)
            raise
        html = raw.decode("utf-8", errors="replace")
        path.write_text(html, encoding="utf-8")
        return html

    def _throttle(self) -> None:
        elapsed = time.monotonic() - self._last_fetch_at
        if elapsed < self.min_interval_s:
            time.sleep(self.min_interval_s - elapsed)
        self._last_fetch_at = time.monotonic()
