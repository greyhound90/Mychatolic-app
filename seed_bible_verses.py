#!/usr/bin/env python3
import json
import logging
import os
import re
import sys
import time
from typing import Any, Dict, Iterable, List, Optional, Tuple

try:
    import requests
except ImportError:
    print("Missing dependency: requests. Install with `pip install requests`.", file=sys.stderr)
    sys.exit(1)

try:
    from supabase import create_client
except ImportError:
    print("Missing dependency: supabase-py. Install with `pip install supabase`.", file=sys.stderr)
    sys.exit(1)


BOOK_ID_MAP: Dict[str, int] = {
    "Kejadian": 1,
    "Keluaran": 2,
    "Imamat": 3,
    "Bilangan": 4,
    "Ulangan": 5,
    "Yosua": 6,
    "Hakim-hakim": 7,
    "Rut": 8,
    "1 Samuel": 9,
    "2 Samuel": 10,
    "1 Raja-raja": 11,
    "2 Raja-raja": 12,
    "1 Tawarikh": 13,
    "2 Tawarikh": 14,
    "Ezra": 15,
    "Nehemia": 16,
    "Tobit": 17,
    "Yudit": 18,
    "Ester": 19,
    "1 Makabe": 20,
    "2 Makabe": 21,
    "Ayub": 22,
    "Mazmur": 23,
    "Amsal": 24,
    "Pengkhotbah": 25,
    "Kidung Agung": 26,
    "Kebijaksanaan Salomo": 27,
    "Sirakh": 28,
    "Yesaya": 29,
    "Yeremia": 30,
    "Ratapan": 31,
    "Barukh": 32,
    "Yehezkiel": 33,
    "Daniel": 34,
    "Hosea": 35,
    "Yoel": 36,
    "Amos": 37,
    "Obaja": 38,
    "Yunus": 39,
    "Mikha": 40,
    "Nahum": 41,
    "Habakuk": 42,
    "Zefanya": 43,
    "Hagai": 44,
    "Zakharia": 45,
    "Maleakhi": 46,
    "Matius": 47,
    "Markus": 48,
    "Lukas": 49,
    "Yohanes": 50,
    "Kisah Para Rasul": 51,
    "Roma": 52,
    "1 Korintus": 53,
    "2 Korintus": 54,
    "Galatia": 55,
    "Efesus": 56,
    "Filipi": 57,
    "Kolose": 58,
    "1 Tesalonika": 59,
    "2 Tesalonika": 60,
    "1 Timotius": 61,
    "2 Timotius": 62,
    "Titus": 63,
    "Filemon": 64,
    "Ibrani": 65,
    "Yakobus": 66,
    "1 Petrus": 67,
    "2 Petrus": 68,
    "1 Yohanes": 69,
    "2 Yohanes": 70,
    "3 Yohanes": 71,
    "Yudas": 72,
    "Wahyu": 73,
}

ROMAN_PREFIX = {"I": "1", "II": "2", "III": "3"}

BOOK_ALIASES = {
    "I Samuel": "1 Samuel",
    "II Samuel": "2 Samuel",
    "I Raja-raja": "1 Raja-raja",
    "II Raja-raja": "2 Raja-raja",
    "I Tawarikh": "1 Tawarikh",
    "II Tawarikh": "2 Tawarikh",
    "I Korintus": "1 Korintus",
    "II Korintus": "2 Korintus",
    "I Tesalonika": "1 Tesalonika",
    "II Tesalonika": "2 Tesalonika",
    "I Timotius": "1 Timotius",
    "II Timotius": "2 Timotius",
    "I Petrus": "1 Petrus",
    "II Petrus": "2 Petrus",
    "I Yohanes": "1 Yohanes",
    "II Yohanes": "2 Yohanes",
    "III Yohanes": "3 Yohanes",
    "Kidung Agung Salomo": "Kidung Agung",
    "Wahyu Yohanes": "Wahyu",
}

DEFAULT_JSON_URL = (
    "https://raw.githubusercontent.com/songofege/alkitab-json/master/edisi/tb/tb.json"
)
DEFAULT_GRAPHQL_URL = "https://bible.sonnylab.com/"
DEFAULT_BATCH_SIZE = 1000

GRAPHQL_QUERY = """
query Chapter($version: Version!, $book: String!, $chapter: Int!) {
  passages(version: $version, book: $book, chapter: $chapter) {
    verses { verse type content }
  }
}
"""


def normalize_book_name(name: str) -> str:
    if not name:
        return name
    normalized = name.replace("\u00a0", " ").strip()
    normalized = re.sub(r"\\s+", " ", normalized)

    roman_match = re.match(r"^(I{1,3})[\\s\\.-]+(.+)$", normalized, flags=re.IGNORECASE)
    if roman_match:
        roman = roman_match.group(1).upper()
        rest = roman_match.group(2).strip()
        if roman in ROMAN_PREFIX:
            normalized = f"{ROMAN_PREFIX[roman]} {rest}"

    normalized = re.sub(r"^(\\d)([A-Za-z])", r"\\1 \\2", normalized)
    return BOOK_ALIASES.get(normalized, normalized)


def to_int(value: Any, fallback: Optional[int] = None) -> Optional[int]:
    if value is None:
        return fallback
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def iter_books_from_json(payload: Any) -> Iterable[Tuple[str, Any]]:
    if isinstance(payload, dict) and "books" in payload:
        for book in payload["books"]:
            if not isinstance(book, dict):
                continue
            name = (
                book.get("book_name")
                or book.get("name")
                or book.get("nama")
                or book.get("book")
            )
            chapters = (
                book.get("chapters")
                or book.get("chapter")
                or book.get("pasal")
                or book.get("chap")
            )
            if name is not None:
                yield name, chapters
        return

    if isinstance(payload, list):
        for book in payload:
            if not isinstance(book, dict):
                continue
            name = (
                book.get("book_name")
                or book.get("name")
                or book.get("nama")
                or book.get("book")
            )
            chapters = (
                book.get("chapters")
                or book.get("chapter")
                or book.get("pasal")
                or book.get("chap")
            )
            if name is not None:
                yield name, chapters
        return

    if isinstance(payload, dict):
        for name, chapters in payload.items():
            yield name, chapters


def iter_chapters(chapters: Any) -> Iterable[Tuple[int, Any]]:
    if isinstance(chapters, list):
        for idx, chapter in enumerate(chapters, start=1):
            if isinstance(chapter, dict):
                chapter_no = to_int(
                    chapter.get("chapter")
                    or chapter.get("no")
                    or chapter.get("pasal")
                    or chapter.get("chapter_number"),
                    fallback=idx,
                )
                verses = (
                    chapter.get("verses")
                    or chapter.get("ayat")
                    or chapter.get("ayat_ayat")
                    or chapter.get("items")
                    or chapter.get("content")
                )
                yield chapter_no, verses
            else:
                yield idx, chapter
        return

    if isinstance(chapters, dict):
        for chapter_no, verses in chapters.items():
            yield to_int(chapter_no, fallback=None), verses


def iter_verses(verses: Any) -> Iterable[Tuple[int, str]]:
    if isinstance(verses, list):
        for idx, verse in enumerate(verses, start=1):
            if isinstance(verse, dict):
                verse_no = to_int(
                    verse.get("verse")
                    or verse.get("ayat")
                    or verse.get("no")
                    or verse.get("number"),
                    fallback=idx,
                )
                content = (
                    verse.get("content")
                    or verse.get("text")
                    or verse.get("isi")
                    or verse.get("value")
                )
                if content is None:
                    continue
                yield verse_no, str(content).strip()
            else:
                yield idx, str(verse).strip()
        return

    if isinstance(verses, dict):
        for verse_no, content in verses.items():
            if content is None:
                continue
            yield to_int(verse_no, fallback=None), str(content).strip()


def fetch_json(url: str, timeout: int = 60) -> Any:
    response = requests.get(url, timeout=timeout)
    response.raise_for_status()
    return response.json()


def fetch_graphql_chapter(
    endpoint: str, book: str, chapter: int, timeout: int = 30
) -> List[Dict[str, Any]]:
    payload = {
        "query": GRAPHQL_QUERY,
        "variables": {"version": "tb", "book": book, "chapter": chapter},
    }
    response = requests.post(endpoint, json=payload, timeout=timeout)
    response.raise_for_status()
    data = response.json()
    if data.get("errors"):
        raise RuntimeError(data["errors"])
    passages = data.get("data", {}).get("passages")
    if not passages:
        return []
    verses = passages.get("verses") or []
    return [v for v in verses if v.get("type") == "content"]


def chunked(items: List[Dict[str, Any]], size: int) -> Iterable[List[Dict[str, Any]]]:
    for idx in range(0, len(items), size):
        yield items[idx : idx + size]


def insert_batch(supabase, table: str, batch: List[Dict[str, Any]], dry_run: bool) -> int:
    if not batch:
        return 0
    if dry_run:
        logging.info("Dry run: would insert %d rows", len(batch))
        return len(batch)
    response = supabase.table(table).insert(batch).execute()
    error = None
    if isinstance(response, dict):
        error = response.get("error") or response.get("errors")
    else:
        error = getattr(response, "error", None) or getattr(response, "errors", None)
    if error:
        raise RuntimeError(error)
    return len(batch)


def load_from_json_source(
    payload: Any,
    batch_size: int,
    supabase,
    table: str,
    dry_run: bool,
) -> int:
    total_inserted = 0
    seen_books = set()
    buffer: List[Dict[str, Any]] = []

    for raw_name, chapters in iter_books_from_json(payload):
        normalized_name = normalize_book_name(str(raw_name))
        if normalized_name not in BOOK_ID_MAP:
            logging.info("Skipping unmapped book: %s", raw_name)
            continue
        seen_books.add(normalized_name)
        book_id = BOOK_ID_MAP[normalized_name]

        for chapter_no, verses in iter_chapters(chapters):
            if chapter_no is None:
                continue
            for verse_no, content in iter_verses(verses):
                if verse_no is None or not content:
                    continue
                buffer.append(
                    {
                        "book_id": book_id,
                        "chapter": int(chapter_no),
                        "verse": int(verse_no),
                        "content": content,
                    }
                )
                if len(buffer) >= batch_size:
                    total_inserted += insert_batch(supabase, table, buffer, dry_run)
                    buffer = []

    if buffer:
        total_inserted += insert_batch(supabase, table, buffer, dry_run)

    for book_name in BOOK_ID_MAP:
        if book_name not in seen_books:
            logging.warning("Missing source data for %s", book_name)

    return total_inserted


def load_from_graphql(
    endpoint: str,
    batch_size: int,
    supabase,
    table: str,
    dry_run: bool,
    sleep_seconds: float,
) -> int:
    total_inserted = 0
    buffer: List[Dict[str, Any]] = []

    for book_name, book_id in BOOK_ID_MAP.items():
        chapter = 1
        found_any = False
        while True:
            verses = fetch_graphql_chapter(endpoint, book_name, chapter)
            if not verses:
                break
            found_any = True
            for verse in verses:
                verse_no = to_int(verse.get("verse"))
                content = verse.get("content")
                if verse_no is None or not content:
                    continue
                buffer.append(
                    {
                        "book_id": book_id,
                        "chapter": int(chapter),
                        "verse": int(verse_no),
                        "content": str(content).strip(),
                    }
                )
                if len(buffer) >= batch_size:
                    total_inserted += insert_batch(supabase, table, buffer, dry_run)
                    buffer = []
            chapter += 1
            if sleep_seconds:
                time.sleep(sleep_seconds)

        if not found_any:
            logging.warning("Missing source data for %s", book_name)

    if buffer:
        total_inserted += insert_batch(supabase, table, buffer, dry_run)

    return total_inserted


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")
    if not supabase_url or not supabase_key:
        logging.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_KEY).")
        sys.exit(1)

    source_mode = os.getenv("BIBLE_SOURCE_MODE", "auto").lower()
    json_url = os.getenv("BIBLE_JSON_URL", DEFAULT_JSON_URL)
    graphql_url = os.getenv("BIBLE_GRAPHQL_URL", DEFAULT_GRAPHQL_URL)
    table = os.getenv("BIBLE_VERSES_TABLE", "bible_verses")
    batch_size = int(os.getenv("BIBLE_BATCH_SIZE", str(DEFAULT_BATCH_SIZE)))
    dry_run = os.getenv("DRY_RUN", "0") == "1"
    sleep_seconds = float(os.getenv("BIBLE_SLEEP_SECONDS", "0.0"))

    supabase = create_client(supabase_url, supabase_key)

    total_inserted = 0
    if source_mode in ("auto", "json"):
        try:
            logging.info("Fetching JSON source: %s", json_url)
            payload = fetch_json(json_url)
            total_inserted = load_from_json_source(
                payload=payload,
                batch_size=batch_size,
                supabase=supabase,
                table=table,
                dry_run=dry_run,
            )
        except Exception as exc:
            if source_mode == "json":
                logging.error("JSON source failed: %s", exc)
                sys.exit(1)
            logging.warning("JSON source failed, falling back to GraphQL: %s", exc)
            total_inserted = load_from_graphql(
                endpoint=graphql_url,
                batch_size=batch_size,
                supabase=supabase,
                table=table,
                dry_run=dry_run,
                sleep_seconds=sleep_seconds,
            )
    else:
        total_inserted = load_from_graphql(
            endpoint=graphql_url,
            batch_size=batch_size,
            supabase=supabase,
            table=table,
            dry_run=dry_run,
            sleep_seconds=sleep_seconds,
        )

    logging.info("Inserted %d verses.", total_inserted)


if __name__ == "__main__":
    main()
