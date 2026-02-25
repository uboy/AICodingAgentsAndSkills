# Eval: task-specifier

## Scenario
User wants to add a new "about" page to a React project.

## Input
"I want to add a simple about page with some text and a contact button."

## Expected Output
- **Title**: Add About page component and route
- **Inputs**: `src/App.tsx`, `src/components/Layout.tsx`
- **Outputs**: `src/pages/About.tsx`, `src/App.tsx`
- **Checklist**:
  - [todo] Create `src/pages/About.tsx` with content and button.
  - [todo] Import `About` page in `src/App.tsx`.
  - [todo] Add route for `/about` in `src/App.tsx`.
  - [todo] Verify page renders correctly.
- **TASK_JSON**: Valid JSON object containing the above fields.
