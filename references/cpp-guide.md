# C++ Best Practices Guide

This reference is used by agents (implementation-developer, code-review-qa, lang-cpp) when working with C/C++ codebases. It defines the conventions, patterns, and tools to follow. Target: modern C++ (C++17 minimum, C++20/23 preferred).

## Project Structure

### Standard Layout
```
project-name/
├── CMakeLists.txt              # Root CMake file
├── CMakePresets.json            # Build presets (debug, release, sanitizers)
├── src/
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── module_a/
│   │   ├── module_a.h
│   │   └── module_a.cpp
│   └── module_b/
│       ├── module_b.h
│       └── module_b.cpp
├── include/                     # Public headers (for libraries)
│   └── project_name/
│       └── public_api.h
├── tests/
│   ├── CMakeLists.txt
│   ├── test_module_a.cpp
│   └── test_module_b.cpp
├── third_party/                 # Vendored or FetchContent deps
└── README.md
```

## CMake — Modern Practices

### Target-Based CMake
```cmake
cmake_minimum_required(VERSION 3.25)
project(my_project LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(my_lib
    src/module_a/module_a.cpp
    src/module_b/module_b.cpp
)
target_include_directories(my_lib PUBLIC include PRIVATE src)
target_compile_options(my_lib PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic -Werror>
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /WX>
)

add_executable(my_app src/main.cpp)
target_link_libraries(my_app PRIVATE my_lib)
```

**Rules:**
- Never use `include_directories()`, `link_libraries()`, or `add_definitions()` (global scope)
- Always use `target_*` variants
- Use `PRIVATE`/`PUBLIC`/`INTERFACE` correctly
- Use FetchContent or CPM for dependencies, not git submodules when possible

### FetchContent for Dependencies
```cmake
include(FetchContent)
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.14.0
)
FetchContent_MakeAvailable(googletest)
```

## Memory Safety & RAII

### Ownership Model
```cpp
// Unique ownership (default choice)
auto widget = std::make_unique<Widget>(args...);
process(std::move(widget));  // Transfer ownership

// Shared ownership (only when truly shared)
auto cache = std::make_shared<Cache>();
registry.add(cache);
worker.set_cache(cache);

// Non-owning reference — raw pointer or reference
void process(const Widget& widget);  // Preferred for non-owning
void process(Widget* widget);        // When nullable

// Non-owning view into contiguous data
void process(std::span<const int> data);

// Non-owning string view
void process(std::string_view name);
```

**Rules:**
- Never use `new`/`delete` directly — use `make_unique`/`make_shared`
- Use `unique_ptr` by default; `shared_ptr` only for true shared ownership
- Use references for non-owning access to guaranteed-existing objects
- Use `std::span` for contiguous ranges, `std::string_view` for strings
- Destructors, move constructors, and move assignments must be `noexcept`

### Rule of Zero
```cpp
// Preferred — let compiler generate everything
struct User {
    std::string name;
    std::string email;
    std::vector<Order> orders;
    // No destructor, no copy/move constructors — all generated correctly
};
```

Only define special members when managing a resource directly (and then follow the Rule of Five).

## Error Handling

### std::expected (C++23)
```cpp
#include <expected>

std::expected<User, Error> find_user(int id) {
    auto row = db.query("SELECT * FROM users WHERE id = ?", id);
    if (!row) {
        return std::unexpected(Error::NotFound);
    }
    return User::from_row(*row);
}

// Usage
auto result = find_user(42);
if (!result) {
    log_error("User not found: {}", result.error());
    return;
}
auto& user = result.value();
```

### std::optional for Nullable Values
```cpp
std::optional<User> find_user(std::string_view email) {
    auto it = users.find(email);
    if (it == users.end()) return std::nullopt;
    return it->second;
}

// Usage
if (auto user = find_user("alice@example.com")) {
    process(*user);
}
```

## Modern C++ Patterns

### Structured Bindings (C++17)
```cpp
auto [name, age, email] = get_user_tuple();

for (const auto& [key, value] : config_map) {
    std::println("{}: {}", key, value);
}
```

### std::variant for Type-Safe Unions
```cpp
using Value = std::variant<int, double, std::string>;

void process(const Value& v) {
    std::visit(overloaded{
        [](int i)                { std::println("int: {}", i); },
        [](double d)             { std::println("double: {}", d); },
        [](const std::string& s) { std::println("string: {}", s); },
    }, v);
}
```

### Concepts (C++20)
```cpp
template<typename T>
concept Serializable = requires(T t, std::ostream& os) {
    { t.serialize(os) } -> std::same_as<void>;
    { T::deserialize(os) } -> std::same_as<T>;
};

void save(const Serializable auto& obj, const std::filesystem::path& path) {
    std::ofstream file(path);
    obj.serialize(file);
}
```

### Ranges (C++20)
```cpp
#include <ranges>

auto active_names = users
    | std::views::filter([](const User& u) { return u.is_active; })
    | std::views::transform([](const User& u) { return u.name; })
    | std::views::take(10);
```

## Concurrency

### std::jthread (C++20) — Auto-Joining Thread
```cpp
{
    std::jthread worker([](std::stop_token token) {
        while (!token.stop_requested()) {
            process_next_item();
        }
    });
    // Automatically joins on scope exit
}
```

### Synchronization
```cpp
// Prefer scoped_lock for multiple mutexes
std::scoped_lock lock(mutex_a, mutex_b);  // Deadlock-free

// Use shared_mutex for read-heavy workloads
std::shared_mutex rw_mutex;
std::shared_lock read_lock(rw_mutex);   // Multiple readers
std::unique_lock write_lock(rw_mutex);  // Exclusive writer
```

## Testing with Google Test

```cpp
#include <gtest/gtest.h>

TEST(UserTest, CreateWithValidInput) {
    auto user = User::create("Alice", "alice@example.com");
    ASSERT_TRUE(user.has_value());
    EXPECT_EQ(user->name(), "Alice");
    EXPECT_EQ(user->email(), "alice@example.com");
}

TEST(UserTest, RejectsEmptyName) {
    auto user = User::create("", "alice@example.com");
    ASSERT_FALSE(user.has_value());
    EXPECT_EQ(user.error(), Error::InvalidName);
}

// Parameterized tests
class ParseTest : public ::testing::TestWithParam<std::pair<std::string, int>> {};

TEST_P(ParseTest, ParsesValidIntegers) {
    auto [input, expected] = GetParam();
    EXPECT_EQ(parse_int(input), expected);
}

INSTANTIATE_TEST_SUITE_P(Integers, ParseTest, ::testing::Values(
    std::make_pair("42", 42),
    std::make_pair("-1", -1),
    std::make_pair("0", 0)
));
```

## Common Pitfalls

### Dangling References
```cpp
// Bug — returns reference to local
std::string_view get_name() {
    std::string name = compute_name();
    return name;  // Dangling! string destroyed at scope exit
}

// Fix — return by value
std::string get_name() {
    std::string name = compute_name();
    return name;  // RVO/NRVO — no copy
}
```

### Use-After-Move
```cpp
auto data = std::make_unique<Data>();
process(std::move(data));
data->field;  // UB! data is null after move

// Fix — don't use moved-from objects (or check explicitly)
```

### Object Slicing
```cpp
class Base { virtual void f(); };
class Derived : public Base { void f() override; int extra; };

Base b = Derived{};  // Sliced! extra is lost
// Fix — use pointers or references for polymorphism
std::unique_ptr<Base> b = std::make_unique<Derived>();
```

## Compiler Flags

### Development
```
-std=c++20 -Wall -Wextra -Wpedantic -Werror
-fsanitize=address,undefined   # ASan + UBSan
-fno-omit-frame-pointer         # Better stack traces
```

### Release
```
-std=c++20 -O2 -DNDEBUG
-flto                           # Link-time optimization
```

### Continuous Integration
Run with all sanitizers: AddressSanitizer, UndefinedBehaviorSanitizer, ThreadSanitizer (separate build — TSan incompatible with ASan).

## Key Libraries

| Domain | Recommended | Notes |
|--------|-------------|-------|
| Testing | Google Test, Catch2 | GTest for larger projects, Catch2 for simplicity |
| Benchmarking | Google Benchmark | Microbenchmarks |
| JSON | nlohmann/json, simdjson | nlohmann for convenience, simdjson for speed |
| HTTP | cpp-httplib, Boost.Beast | cpp-httplib for simplicity |
| Logging | spdlog | Fast, header-only |
| CLI | CLI11 | Modern argument parser |
| Formatting | std::format (C++20), fmt | fmt for pre-C++20 |
| Networking | Boost.Asio, standalone Asio | Async I/O |
