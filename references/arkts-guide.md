# ArkTS Best Practices Guide

This reference is used by agents (implementation-developer, code-review-qa, lang-arkts) when working with HarmonyOS/ArkTS codebases. It defines the conventions, patterns, and restrictions specific to ArkTS and ArkUI development.

## ArkTS vs TypeScript

ArkTS is based on TypeScript but imposes strict restrictions for performance and safety. Code that is valid TypeScript may NOT compile in ArkTS.

### Key Restrictions

| Feature | TypeScript | ArkTS |
|---------|-----------|-------|
| `any` / `unknown` | Allowed | Prohibited |
| Union types | Full support | Limited (enums preferred) |
| Structural typing | Object literals match interfaces | Nominal only — must use class/struct |
| Type assertions (`as`) | Allowed | Prohibited |
| `eval()` | Available | Prohibited |
| Dynamic property access | `obj[key]` | Not allowed on typed objects |
| Utility types (`Partial`, `Pick`) | Available | Not available |
| Destructuring | Full support | Limited contexts |
| `namespace` | Available | Not available (modules only) |
| `require()` | CommonJS | Not available (ESM `import` only) |

### Practical Implications
```typescript
// TypeScript — works
interface Config { host: string; port: number; }
const config: Config = { host: "localhost", port: 3000 };

// ArkTS — may NOT work (structural typing)
// Must use class instantiation:
class Config {
  host: string = ""
  port: number = 0
}
let config = new Config()
config.host = "localhost"
config.port = 3000
```

## Project Structure

### Standard HarmonyOS Module
```
entry/
├── src/
│   └── main/
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── EntryAbility.ets       # UIAbility entry point
│       │   ├── pages/
│       │   │   ├── Index.ets              # Main page
│       │   │   └── Detail.ets             # Detail page
│       │   ├── components/
│       │   │   ├── Header.ets             # Reusable components
│       │   │   └── UserCard.ets
│       │   ├── model/
│       │   │   └── UserModel.ets          # Data models
│       │   ├── service/
│       │   │   └── ApiService.ets         # Network/data services
│       │   └── common/
│       │       ├── Constants.ets          # App constants
│       │       └── Utils.ets              # Utility functions
│       └── resources/
│           ├── base/
│           │   ├── element/               # Strings, colors, dimensions
│           │   ├── media/                 # Images, icons
│           │   └── profile/
│           │       └── main_pages.json    # Page routing config
│           └── rawfile/                   # Raw assets
├── build-profile.json5
└── oh-package.json5
```

## ArkUI Component Patterns

### Basic Component Structure
```typescript
@Entry
@Component
struct IndexPage {
  @State message: string = "Hello World"
  @State isLoading: boolean = false

  build() {
    Column() {
      Text(this.message)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })

      Button("Load Data")
        .onClick(() => {
          this.loadData()
        })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
  }

  private async loadData(): Promise<void> {
    this.isLoading = true
    // ... fetch data
    this.isLoading = false
  }
}
```

### State Management Patterns

#### @State — Component-Local State
```typescript
@Component
struct Counter {
  @State count: number = 0   // Owned by this component, triggers re-render

  build() {
    Row() {
      Button("-").onClick(() => { this.count-- })
      Text(`${this.count}`).margin({ left: 12, right: 12 })
      Button("+").onClick(() => { this.count++ })
    }
  }
}
```

#### @Prop — One-Way Binding (Parent → Child)
```typescript
@Component
struct ChildView {
  @Prop title: string    // Copy from parent. Child changes don't affect parent.

  build() {
    Text(this.title).fontSize(20)
  }
}

@Entry
@Component
struct ParentView {
  @State pageTitle: string = "Home"

  build() {
    ChildView({ title: this.pageTitle })
  }
}
```

#### @Link — Two-Way Binding
```typescript
@Component
struct ToggleSwitch {
  @Link isOn: boolean    // Shared reference. Changes propagate both ways.

  build() {
    Toggle({ type: ToggleType.Switch, isOn: this.isOn })
      .onChange((value: boolean) => { this.isOn = value })
  }
}

@Entry
@Component
struct SettingsPage {
  @State darkMode: boolean = false

  build() {
    Column() {
      Text(`Dark mode: ${this.darkMode ? 'ON' : 'OFF'}`)
      ToggleSwitch({ isOn: $darkMode })  // $ prefix for @Link
    }
  }
}
```

#### @Provide / @Consume — Ancestor-to-Descendant
```typescript
@Entry
@Component
struct App {
  @Provide('theme') currentTheme: string = 'light'

  build() {
    Column() {
      // Deep child can @Consume without prop drilling
      PageContent()
    }
  }
}

@Component
struct DeepChild {
  @Consume('theme') currentTheme: string

  build() {
    Text(`Theme: ${this.currentTheme}`)
  }
}
```

#### @Observed / @ObjectLink — Nested Object Observation
```typescript
@Observed
class Task {
  title: string
  isComplete: boolean

  constructor(title: string) {
    this.title = title
    this.isComplete = false
  }
}

@Component
struct TaskItem {
  @ObjectLink task: Task    // Observes changes to task properties

  build() {
    Row() {
      Checkbox({ isChecked: this.task.isComplete })
        .onChange((value: boolean) => { this.task.isComplete = value })
      Text(this.task.title)
    }
  }
}
```

### @Builder for Reusable UI Fragments
```typescript
@Entry
@Component
struct MyPage {
  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .margin({ top: 16, bottom: 8 })
  }

  build() {
    Column() {
      this.SectionHeader("Profile")
      // ... profile content
      this.SectionHeader("Settings")
      // ... settings content
    }
  }
}
```

## Performance Best Practices

### LazyForEach for Large Lists
```typescript
class DataSource implements IDataSource {
  private data: string[] = []

  totalCount(): number { return this.data.length }
  getData(index: number): string { return this.data[index] }
  // ... registerDataChangeListener, unregisterDataChangeListener
}

@Entry
@Component
struct ListPage {
  private dataSource: DataSource = new DataSource()

  build() {
    List() {
      LazyForEach(this.dataSource, (item: string, index: number) => {
        ListItem() {
          Text(item)
        }
      }, (item: string) => item)   // Key generator function
    }
  }
}
```

**Never** use `ForEach` for lists larger than ~50 items — use `LazyForEach` with `IDataSource`.

### Key Generation for ForEach
```typescript
// Always provide unique keys
ForEach(this.items, (item: Item) => {
  ItemView({ item: item })
}, (item: Item) => item.id.toString())  // Unique key function
```

Missing keys cause incorrect diffing, stale UI, and performance issues.

## Ability Lifecycle

### UIAbility
```typescript
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    // Initialize app-level resources
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    // Load the main page
    windowStage.loadContent('pages/Index')
  }

  onForeground() {
    // App comes to foreground — resume operations
  }

  onBackground() {
    // App goes to background — release heavy resources
  }

  onWindowStageDestroy() {
    // Clean up window resources
  }

  onDestroy() {
    // Final cleanup
  }
}
```

**Critical**: Release resources in `onBackground()` — camera, location, heavy computations. HarmonyOS may kill background apps aggressively.

## Data Persistence

### Preferences (Key-Value)
```typescript
import preferences from '@ohos.data.preferences'

const STORE_NAME = 'settings'

async function saveSetting(key: string, value: string): Promise<void> {
  const pref = await preferences.getPreferences(this.context, STORE_NAME)
  await pref.put(key, value)
  await pref.flush()
}

async function loadSetting(key: string): Promise<string> {
  const pref = await preferences.getPreferences(this.context, STORE_NAME)
  return await pref.get(key, '') as string
}
```

### AppStorage + PersistentStorage
```typescript
// Initialize persistent storage (once, at app start)
PersistentStorage.persistProp('language', 'en')
PersistentStorage.persistProp('fontSize', 16)

// Access in components
@Entry
@Component
struct SettingsPage {
  @StorageLink('language') language: string = 'en'
  @StorageLink('fontSize') fontSize: number = 16

  build() {
    Column() {
      Text(`Language: ${this.language}`)
      Text(`Font size: ${this.fontSize}`)
    }
  }
}
```

## Common Pitfalls

### 1. Missing @Entry
Every page component needs `@Entry`. Without it, the page renders blank with no error.

### 2. Nested Object Changes Not Detected
```typescript
// Bug — @State doesn't deep-watch
@State user: User = new User("Alice")
// this.user.name = "Bob"  — UI does NOT update

// Fix — use @Observed on the class + @ObjectLink in child
// Or reassign the entire object:
this.user = new User("Bob")
```

### 3. Confusing @Prop and @Link
- `@Prop` = one-way copy (parent → child). Use `property: value` syntax.
- `@Link` = two-way reference (parent ↔ child). Use `property: $parentState` syntax.

### 4. Imperative Logic in build()
```typescript
// Bug — imperative code in build()
build() {
  let filtered = this.items.filter(i => i.active)  // Not reactive!
  ForEach(filtered, ...)
}

// Fix — compute in a getter or method, reference @State
get activeItems(): Item[] {
  return this.items.filter(i => i.active)
}
```

### 5. TypeScript Patterns That Fail in ArkTS
```typescript
// Fails — union type
let value: string | number = "hello"

// Fails — type assertion
let name = (data as User).name

// Fails — dynamic property access
let key = "name"
let value = obj[key]

// Fails — object literal matching interface
interface I { x: number }
let obj: I = { x: 1 }  // May fail in strict ArkTS
```

## Official Documentation References

- [ArkTS Language Guide](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-get-started)
- [ArkUI Component Reference](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkui-ts-components)
- [State Management](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-state-management)
- [UIAbility Lifecycle](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/uiability-lifecycle)
