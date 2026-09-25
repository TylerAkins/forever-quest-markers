"""Rate-limited HTTP client with on-disk HTML cache."""

from __future__ import annotations

import hashlib
import re
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
DEFAULT_MIN_INTERVAL_S = 1.25
_DEFAULT_HEADERS = {
    "User-Agent": USER_AGENT,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "identity",
    "Referer": "https://www.wowhead.com/forever",
}


class WowheadClient:
    def __init__(
        self,
        cache_dir: Path,
        min_interval_s: float = DEFAULT_MIN_INTERVAL_S,
        batch_size: int = 0,
        batch_pause_s: float = 0.0,
    ) -> None:
        self.cache_dir = cache_dir
        self.min_interval_s = min_interval_s
        self.batch_size = batch_size
        self.batch_pause_s = batch_pause_s
        self._last_fetch_at = 0.0
        self._network_fetches = 0
        self._use_curl = False
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:32]
        return self.cache_dir / f"{digest}.html"

    def get_html(self, url: str, *, force: bool = False) -> str:
        path = self._cache_path(url)
        if not force and path.is_file():
            return path.read_text(encoding="utf-8", errors="replace")

        if self._use_curl:
            return self._fetch_store(url, path, self._fetch_curl)

        last_error: Exception | None = None
        for attempt in range(6):
            self._throttle()
            try:
                html = self._fetch_urllib(url)
            except urllib.error.HTTPError as exc:
                last_error = exc
                if exc.code in (403, 429, 503):
                    wait = min(60, 5 * (2**attempt))
                    print(f"  HTTP {exc.code}, retry in {wait}s", flush=True)
                    time.sleep(wait)
                    continue
                raise
            except OSError as exc:
                last_error = exc
                if _is_cert_verify_failure(exc):
                    print(
                        "  Python cannot verify HTTPS certificates; using curl for the rest of this run",
                        flush=True,
                    )
                    self._use_curl = True
                    return self._fetch_store(url, path, self._fetch_curl)
                wait = min(30, 2 * (2**attempt))
                print(f"  network error ({exc}); retry in {wait}s", flush=True)
                time.sleep(wait)
                continue

            if _looks_like_block_page(html):
                last_error = RuntimeError("Wowhead returned a block/challenge page")
                time.sleep(min(60, 5 * (2**attempt)))
                continue

            path.write_text(html, encoding="utf-8")
            self._note_network_fetch()
            return html

        try:
            html = self._fetch_curl(url)
        except subprocess.CalledProcessError as exc:
            if last_error is not None:
                raise last_error from exc
            raise

        return self._store_html(url, path, html)

    def _fetch_store(self, url: str, path: Path, fetch) -> str:
        self._throttle()
        html = fetch(url)
        return self._store_html(url, path, html)

    def _store_html(self, url: str, path: Path, html: str) -> str:
        if _looks_like_block_page(html):
            raise RuntimeError(f"Wowhead blocked fetch for {url}")
        path.write_text(html, encoding="utf-8")
        self._note_network_fetch()
        return html

    def _note_network_fetch(self) -> None:
        self._network_fetches += 1
        if self.batch_size > 0 and self.batch_pause_s > 0 and self._network_fetches % self.batch_size == 0:
            time.sleep(self.batch_pause_s)

    def _fetch_urllib(self, url: str) -> str:
        request = urllib.request.Request(url, headers=dict(_DEFAULT_HEADERS))
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read()
        return raw.decode("utf-8", errors="replace")

    def _fetch_curl(self, url: str) -> str:
        result = subprocess.run(
            [
                "curl",
                "-fsSL",
                "-A",
                USER_AGENT,
                "-H",
                "Accept-Language: en-US,en;q=0.9",
                "-H",
                "Referer: https://www.wowhead.com/forever",
                url,
            ],
            check=True,
            capture_output=True,
            timeout=120,
        )
        return result.stdout.decode("utf-8", errors="replace")

    def _throttle(self) -> None:
        elapsed = time.monotonic() - self._last_fetch_at
        if elapsed < self.min_interval_s:
            time.sleep(self.min_interval_s - elapsed)
        self._last_fetch_at = time.monotonic()


def slugify_quest_name(name: str | None) -> str:
    if not name:
        return ""
    text = name.lower()
    text = re.sub(r"[''']", "", text)
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def quest_detail_url(quest_id: int, name: str | None = None) -> str:
    slug = slugify_quest_name(name)
    if slug:
        return f"https://www.wowhead.com/forever/quest={quest_id}/{slug}"
    return f"https://www.wowhead.com/forever/quest={quest_id}"


def _is_cert_verify_failure(exc: BaseException) -> bool:
    text = str(exc).lower()
    return "certificate_verify_failed" in text or "certificate verify failed" in text


def _looks_like_block_page(html: str) -> bool:
    sample = html[:8000].lower()
    if len(html) < 500:
        return True
    if "captcha" in sample or "access denied" in sample:
        return True
    if "wowhead" not in sample and "zamimg" not in sample:
        return True
    return False
