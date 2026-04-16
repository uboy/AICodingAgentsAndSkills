# Context Bundles

Pre-assembled context packages for common task types. Load only the bundle you need — saves tokens by avoiding irrelevant file reads.

## How Bundles Work

1. **Identify** the task type (e.g., "fix auth bug", "add API endpoint", "review PR")
2. **Load** the matching bundle (paste content before your question)
3. **Ask** your question — agent already has the right context

## Why This Saves Tokens

Without bundles:
```
Request 1: [AGENTS.md 3000tok] + [file A 2000tok] + [file B 1500tok] → "find bug"
Request 2: [AGENTS.md 3000tok] + [file C 1800tok] + [file D 1200tok] → "fix it"
Total: 14500 tokens (no cache between requests — different context)
```

With bundles:
```
Request 1: [AGENTS.md 3000tok] + [auth-bundle 4000tok] → "find bug"
Request 2: [AGENTS.md 3000tok] + [auth-bundle 4000tok] → "fix it"
Total: 14000 tokens, 7000 cached from Request 1 → only 7000 charged
```

## Bundle Templates

Copy and customize these for your project:

### auth-system

```
# Authentication Context Bundle
## Files
- src/auth/login.py — login flow, session creation
- src/auth/middleware.py — auth middleware, token validation
- src/auth/models.py — User, Session, Token models
- src/auth/config.py — JWT config, secret loading
## Key Patterns
- JWT-based auth with refresh tokens
- Password hashing: bcrypt
- Session expiry: 24h access, 7d refresh
## Common Issues
- Token expiry edge cases
- Missing auth middleware on new routes
```

### api-endpoints

```
# API Context Bundle
## Entry Point
- src/api/__init__.py — router setup
- src/api/app.py — FastAPI/Express app creation
## Core Files
- src/api/routes/*.py — all route handlers
- src/api/schemas/*.py — request/response schemas
## Database
- src/db/session.py — DB connection pool
- src/db/migrations/ — migration files
## Patterns
- RESTful conventions
- Error handling middleware
- Pagination: offset/limit
```

### ci-failure

```
# CI/CD Context Bundle
## Pipeline Config
- .github/workflows/ci.yml — CI pipeline definition
- Makefile / package.json — build commands
## Test Files
- tests/ — test structure and patterns
- pytest.ini / jest.config.js — test config
## Build
- Dockerfile — container build steps
- docker-compose.yml — local dev environment
```

### study-materials

```
# Study Materials Context Bundle
## Sources
- Lecture 1: [path/to/file] — key topics
- Lecture 2: [path/to/file] — key topics
- Slides: [path/to/file] — key topics
## Key Concepts
- [Concept 1]: brief description
- [Concept 2]: brief description
## Assignment Requirements
- Type: essay / case / presentation
- Word/slide limit: N
- Citation format: inline / footnote
```

## Creating Your Own Bundles

1. Create a file: `bundles/<name>.md`
2. Include: file list, key patterns, common issues
3. Keep under 3000 tokens for effective caching
4. One bundle = one logical domain
