import threading
from contextlib import contextmanager
from typing import Dict, Iterable, Tuple


class ApiCallCounter:
    _local = threading.local()

    def __init__(self) -> None:
        self._counts: Dict[str, int] = {}
        self._total = 0

    @classmethod
    def current(cls) -> "ApiCallCounter | None":
        return getattr(cls._local, "counter", None)

    @classmethod
    def record_current(cls, label: str, count: int = 1) -> None:
        counter = cls.current()
        if counter is None:
            return
        counter.record(label, count=count)

    @classmethod
    @contextmanager
    def track(cls):
        prev = cls.current()
        counter = ApiCallCounter()
        cls._local.counter = counter
        try:
            yield counter
        finally:
            cls._local.counter = prev

    def record(self, label: str, count: int = 1) -> None:
        safe_label = (label or "unknown").strip() or "unknown"
        self._counts[safe_label] = self._counts.get(safe_label, 0) + count
        self._total += count

    def summary(self) -> Dict[str, object]:
        return {
            "total": self._total,
            "by_label": list(self._ordered_counts()),
        }

    def format_summary(self) -> str:
        parts = [f"total={self._total}"]
        for label, count in self._ordered_counts():
            parts.append(f"{label}={count}")
        return " ".join(parts)

    def _ordered_counts(self) -> Iterable[Tuple[str, int]]:
        return sorted(self._counts.items(), key=lambda item: (-item[1], item[0]))
