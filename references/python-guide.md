# Python Best Practices Guide

This reference is used by agents (implementation-developer, code-review-qa, lang-python) when working with Python codebases. It defines the conventions, patterns, and tools to follow.

## Project Structure

### Standard Layout (src layout)
```
project-name/
├── pyproject.toml          # Single source of truth for config
├── src/
│   └── package_name/
│       ├── __init__.py
│       ├── main.py
│       ├── models/
│       ├── services/
│       └── utils/
├── tests/
│   ├── conftest.py         # Shared fixtures
│   ├── unit/
│   └── integration/
├── .python-version         # Pin Python version
└── README.md
```

Use `src/` layout to prevent accidental imports from the project root. Flat layout is acceptable for small scripts or packages.

### pyproject.toml
```toml
[project]
name = "package-name"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.27",
]

[project.optional-dependencies]
dev = ["pytest>=8.0", "mypy>=1.10", "ruff>=0.5"]

[tool.ruff]
target-version = "py311"
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "TCH"]

[tool.mypy]
strict = true
python_version = "3.11"

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
```

Use **uv** for dependency management (faster than pip/poetry). Use **ruff** for linting and formatting (replaces flake8, isort, black).

## Type Hints

### Modern Syntax (Python 3.10+)
```python
# Good — modern syntax
def process(items: list[str], config: dict[str, int] | None = None) -> bool: ...

# Avoid — old syntax
from typing import List, Dict, Optional, Union
def process(items: List[str], config: Optional[Dict[str, int]] = None) -> bool: ...
```

### When to Use Which Type
```python
from dataclasses import dataclass
from typing import TypedDict, Protocol

# Dataclass — mutable data with behavior
@dataclass
class User:
    name: str
    email: str
    def display_name(self) -> str: ...

# Frozen dataclass — immutable value objects
@dataclass(frozen=True)
class Coordinate:
    x: float
    y: float

# TypedDict — typed dictionaries (for JSON-like data)
class UserResponse(TypedDict):
    id: int
    name: str
    email: str

# Protocol — structural typing (duck typing with type safety)
class Readable(Protocol):
    def read(self, n: int = -1) -> bytes: ...

# Pydantic — validation + serialization (API boundaries)
from pydantic import BaseModel
class CreateUserRequest(BaseModel):
    name: str
    email: str
```

### Avoid `Any`
Prefer `object` for truly unknown types. Use `Any` only as a last resort escape hatch. Configure mypy with `strict = true`.

## Async Patterns

### When to Use Async
Use async when you have **I/O-bound concurrency** — multiple network calls, database queries, or file operations that can overlap. Do NOT use async for CPU-bound work (use `multiprocessing` or `concurrent.futures.ProcessPoolExecutor`).

### TaskGroup (Python 3.11+)
```python
async def fetch_all(urls: list[str]) -> list[Response]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch(url)) for url in urls]
    return [t.result() for t in tasks]
```

### Avoid Blocking the Event Loop
```python
# Bad — blocks the event loop
data = requests.get(url)  # synchronous HTTP in async code

# Good — use async HTTP client
async with httpx.AsyncClient() as client:
    data = await client.get(url)

# If you must call sync code from async:
result = await asyncio.to_thread(blocking_function, arg1, arg2)
```

## Testing with pytest

### Fixtures
```python
# conftest.py
import pytest

@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.rollback()
    session.close()

@pytest.fixture
def sample_user(db_session):
    user = User(name="test", email="test@example.com")
    db_session.add(user)
    db_session.flush()
    return user
```

### Parametrize
```python
@pytest.mark.parametrize("input_val, expected", [
    ("hello", "HELLO"),
    ("", ""),
    ("Hello World", "HELLO WORLD"),
])
def test_uppercase(input_val: str, expected: str):
    assert to_upper(input_val) == expected
```

### Testing Async Code
```python
import pytest

@pytest.mark.asyncio
async def test_fetch_user():
    user = await fetch_user(user_id=1)
    assert user.name == "Alice"
```

### Mocking
```python
from unittest.mock import AsyncMock, patch

async def test_service_calls_api():
    mock_client = AsyncMock()
    mock_client.get.return_value = Response(200, json={"id": 1})

    service = UserService(client=mock_client)
    result = await service.get_user(1)

    mock_client.get.assert_called_once_with("/users/1")
```

## Common Pitfalls

### Mutable Default Arguments
```python
# Bug — shared list across all calls
def add_item(item, items=[]):
    items.append(item)
    return items

# Fix
def add_item(item, items: list | None = None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### Late Binding Closures
```python
# Bug — all lambdas capture the same variable
funcs = [lambda: i for i in range(5)]
[f() for f in funcs]  # [4, 4, 4, 4, 4]

# Fix — default argument captures current value
funcs = [lambda i=i: i for i in range(5)]
[f() for f in funcs]  # [0, 1, 2, 3, 4]
```

### Exception Handling
```python
# Bad — catches everything, hides bugs
try:
    process()
except:
    pass

# Bad — too broad
try:
    process()
except Exception:
    logger.error("failed")

# Good — specific exceptions, with context
try:
    result = api_client.fetch(url)
except httpx.TimeoutException:
    logger.warning("API timeout for %s", url)
    raise
except httpx.HTTPStatusError as e:
    logger.error("API error %d: %s", e.response.status_code, e.response.text)
    raise ServiceError(f"API returned {e.response.status_code}") from e
```

## Logging

```python
import logging

logger = logging.getLogger(__name__)

# Use lazy formatting (not f-strings) for performance
logger.info("Processing user %s with %d items", user_id, len(items))

# Use structlog for structured logging in larger projects
import structlog
log = structlog.get_logger()
log.info("user_processed", user_id=user_id, item_count=len(items))
```

## Key Libraries by Domain

| Domain | Recommended | Notes |
|--------|-------------|-------|
| HTTP client | httpx | Async support, modern API |
| Web framework | FastAPI, Litestar | Async, type-safe |
| ORM | SQLAlchemy 2.0 | With typed query API |
| Validation | Pydantic v2 | Fast, type-safe |
| Testing | pytest | With pytest-asyncio |
| Linting | ruff | Replaces flake8+isort+black |
| Type checking | mypy, pyright | Use strict mode |
| Task queue | Celery, arq | arq for async |
| CLI | typer, click | typer for type hints |
