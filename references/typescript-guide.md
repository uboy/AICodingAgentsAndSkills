# TypeScript Best Practices Guide

This reference is used by agents (implementation-developer, code-review-qa, lang-typescript) when working with TypeScript/JavaScript codebases. It defines the conventions, patterns, and tools to follow.

## Project Configuration

### tsconfig.json — Strict Baseline
```jsonc
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "moduleResolution": "bundler",
    "module": "ESNext",
    "target": "ES2022",
    "lib": ["ES2022"],
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

Always use `strict: true`. Enable `noUncheckedIndexedAccess` to catch array/object access bugs. Use `exactOptionalPropertyTypes` to distinguish between `undefined` and missing.

### package.json
```jsonc
{
  "type": "module",           // ESM by default
  "engines": { "node": ">=20" }
}
```

Use ESM (`import`/`export`) in all new code. Avoid CommonJS (`require`).

## Type System Patterns

### Discriminated Unions for State
```typescript
// Model states explicitly — not with optional fields
type RequestState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: User[] }
  | { status: "error"; error: Error };

function render(state: RequestState) {
  switch (state.status) {
    case "idle": return "Ready";
    case "loading": return "Loading...";
    case "success": return state.data.map(renderUser);  // data is narrowed
    case "error": return `Error: ${state.error.message}`;
  }
}
```

### Use `satisfies` for Type Validation
```typescript
const config = {
  port: 3000,
  host: "localhost",
} satisfies ServerConfig;
// Type is inferred as { port: number; host: string }
// NOT widened to ServerConfig
```

### Branded Types for Nominal Typing
```typescript
type UserId = string & { readonly __brand: unique symbol };
type OrderId = string & { readonly __brand: unique symbol };

function getUser(id: UserId): User { ... }
// getUser(orderId) — compile error! Even though both are strings
```

### Avoid `any`
```typescript
// Bad
function parse(data: any) { return data.name; }

// Good — use unknown + type guard
function parse(data: unknown): string {
  if (typeof data === "object" && data !== null && "name" in data) {
    return String((data as { name: unknown }).name);
  }
  throw new Error("Invalid data");
}

// Better — use Zod for runtime validation
import { z } from "zod";
const UserSchema = z.object({ name: z.string(), age: z.number() });
type User = z.infer<typeof UserSchema>;

function parse(data: unknown): User {
  return UserSchema.parse(data);
}
```

### Utility Types
```typescript
// Extract specific fields
type UserPreview = Pick<User, "id" | "name" | "avatar">;

// Make all fields optional
type PartialUser = Partial<User>;

// Make specific fields required
type CreateUser = Required<Pick<User, "name" | "email">> & Partial<User>;

// Record for typed dictionaries
type UserMap = Record<UserId, User>;

// Exclude from union
type NonErrorState = Exclude<RequestState, { status: "error" }>;
```

## Error Handling

### Result Pattern over Exceptions
```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function parseConfig(raw: string): Result<Config, ParseError> {
  try {
    const data = JSON.parse(raw);
    return { ok: true, value: validateConfig(data) };
  } catch (e) {
    return { ok: false, error: new ParseError("Invalid config", { cause: e }) };
  }
}

// Usage — forces error handling
const result = parseConfig(input);
if (!result.ok) {
  logger.error("Config parse failed", result.error);
  return fallbackConfig;
}
// result.value is narrowed to Config here
```

### Custom Error Classes
```typescript
class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = "AppError";
  }
}

// Chain errors with cause
throw new AppError("Failed to create user", "USER_CREATE_FAILED", {
  cause: originalError,
});
```

## React Patterns (when applicable)

### Component Typing
```typescript
// Prefer function declarations with typed props
interface UserCardProps {
  user: User;
  onEdit?: (id: string) => void;
}

function UserCard({ user, onEdit }: UserCardProps) {
  return (
    <div>
      <h2>{user.name}</h2>
      {onEdit && <button onClick={() => onEdit(user.id)}>Edit</button>}
    </div>
  );
}
```

### Custom Hooks
```typescript
function useDebounce<T>(value: T, delayMs: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);
  return debouncedValue;
}
```

## Node.js Patterns

### Graceful Shutdown
```typescript
const server = app.listen(port);

function shutdown(signal: string) {
  console.log(`${signal} received, shutting down gracefully...`);
  server.close(() => {
    db.disconnect().then(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000); // Force exit after 10s
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

### Environment Variables with Validation
```typescript
import { z } from "zod";

const EnvSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  API_KEY: z.string().min(1),
});

export const env = EnvSchema.parse(process.env);
```

## Testing with Vitest

```typescript
import { describe, it, expect, vi } from "vitest";

describe("UserService", () => {
  it("creates a user with valid input", async () => {
    const mockRepo = { save: vi.fn().mockResolvedValue({ id: "1", name: "Alice" }) };
    const service = new UserService(mockRepo);

    const result = await service.create({ name: "Alice", email: "alice@test.com" });

    expect(result.ok).toBe(true);
    expect(mockRepo.save).toHaveBeenCalledOnce();
  });

  it("returns error for duplicate email", async () => {
    const mockRepo = { save: vi.fn().mockRejectedValue(new UniqueConstraintError()) };
    const service = new UserService(mockRepo);

    const result = await service.create({ name: "Alice", email: "taken@test.com" });

    expect(result.ok).toBe(false);
    expect(result.error.code).toBe("DUPLICATE_EMAIL");
  });
});
```

## Common Pitfalls

### Object.keys() Returns string[]
```typescript
const obj = { a: 1, b: 2 } as const;
Object.keys(obj).forEach((key) => {
  // key is string, NOT "a" | "b"
  obj[key]; // Error with noUncheckedIndexedAccess

  // Fix: use type assertion or Object.entries
});

// Better
Object.entries(obj).forEach(([key, value]) => {
  console.log(key, value); // value is correctly typed
});
```

### Array.sort() Mutates
```typescript
const sorted = [...items].sort((a, b) => a.name.localeCompare(b.name));
// Don't: items.sort() — mutates the original array
```

### Optional Chaining with Nullish Coalescing
```typescript
// Good
const name = user?.profile?.displayName ?? "Anonymous";

// Bad — || treats 0 and "" as falsy
const count = response.total || 10; // Bug: 0 becomes 10
const count = response.total ?? 10; // Correct: only null/undefined → 10
```

## Key Libraries by Domain

| Domain | Recommended | Notes |
|--------|-------------|-------|
| Validation | Zod | Runtime + type inference |
| HTTP client | ky, ofetch | Modern fetch wrappers |
| Web framework | Hono, Fastify | Hono for edge, Fastify for Node |
| ORM | Drizzle, Prisma | Drizzle for SQL-first, Prisma for schema-first |
| Testing | Vitest | Jest-compatible, faster |
| E2E testing | Playwright | Cross-browser |
| Linting | ESLint + @typescript-eslint | Or Biome for all-in-one |
| Formatting | Prettier, Biome | Biome is faster |
| State (React) | Zustand, Jotai | Zustand for global, Jotai for atomic |
| Date/time | date-fns, Temporal | Avoid moment.js |
