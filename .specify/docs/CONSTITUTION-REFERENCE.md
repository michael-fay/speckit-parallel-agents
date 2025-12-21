# Cross-Platform HTML Renderer - Project Constitution

## Purpose

This constitution defines the core principles, constraints, and quality standards for the cross-platform HTML renderer project. These principles override all other considerations and must be followed without exception.

## Core Principles

### 1. Test-Driven Development (Absolute)

**Principle**: No implementation code exists without a failing test first.

**Rules**:
- Every behavior must have a test that fails before implementation
- Tests describe expected behavior, not implementation details
- Run tests via CLI to observe actual failures before writing code
- One behavior, one test, one implementation cycle (red-green-refactor)
- YAGNI: Don't add code until a test requires it

**Test Style**:
- ✅ Good: "should render bold tag as Text with fontWeight bold"
- ❌ Bad: "should have a bold renderer"
- Focus on observable behavior, not internal structure

**Workflow**:
```
1. Write one test for one behavior
2. Run test → observe failure (RED)
3. Write minimal implementation to pass
4. Run test → observe success (GREEN)
5. Refactor if needed
6. Repeat for next behavior
```

**No Exceptions**: This applies to bug fixes, features, refactoring, everything.

---

### 2. Zero Tolerance for Ignores

**Principle**: Never suppress errors, warnings, or tests.

**Prohibited**:
- `eslint-disable` or `eslint-disable-next-line`
- `@ts-ignore` or `@ts-expect-error`
- `test.skip` or `test.todo` or `xit`
- `// prettier-ignore`
- `any` type without explicit justification

**Instead**:
- Fix the underlying issue
- Refactor to satisfy the linter/type checker
- Update configuration if rule is genuinely incorrect
- Document `any` with JSDoc explaining why it's required + get human approval

**Why**: Ignores hide real problems and accumulate tech debt.

---

### 3. TypeScript Strict Mode

**Principle**: All code uses TypeScript strict mode with no escape hatches.

**Rules**:
- `strict: true` in tsconfig.json
- `noImplicitAny: true`
- `strictNullChecks: true`
- `strictFunctionTypes: true`
- All exported functions/components have explicit return types

**Type Safety**:
- Prefer union types over `any`
- Use `unknown` instead of `any` for truly dynamic data
- Exhaustive pattern matching with never checks
- Avoid type assertions (`as`) unless absolutely necessary

---

### 4. Pure Components & Functions

**Principle**: All React components are pure and stateless. No side effects except in designated hooks.

**Rules**:
- HTMLText component is stateless (no useState, useEffect)
- All functions are pure (same input → same output)
- No global state access
- No navigation imports
- Props in, rendering out

**Internal State**:
- Parsing/memoization is acceptable (useMemo)
- Platform detection is acceptable (Platform.OS)
- Context for configuration is acceptable (useContext)

**Why**: Pure components are predictable, testable, and work everywhere.

---

### 5. Cross-Platform Parity

**Principle**: Visual and behavioral parity between native (iOS/Android) and web platforms.

**Rules**:
- Same HTML input produces visually identical output across platforms
- Same props work identically on all platforms
- Accessibility works consistently everywhere
- Performance within 20% across platforms

**Testing**:
- Visual regression tests on all platforms
- Snapshot tests for each platform
- Manual QA on iOS, Android, Web browsers
- Accessibility audit on all platforms

**Acceptable Differences**:
- Font rendering variations (OS-level)
- Touch target sizes (platform conventions)
- Default system colors (respect platform themes)

---

### 6. Accessibility First

**Principle**: WCAG AA compliance is non-negotiable, not a nice-to-have.

**Rules**:
- All interactive elements must be keyboard accessible
- All content must have proper semantic roles
- Color contrast must meet WCAG AA standards (4.5:1 for text)
- Screen reader support must work on iOS VoiceOver, Android TalkBack, Web screen readers

**Implementation**:
- Use semantic HTML on web (not div soup)
- Add proper accessibility props on native (accessibilityRole, accessibilityLabel)
- Test with actual screen readers, not just automated tools

---

### 7. Bundle Size Discipline

**Principle**: Every byte matters. Target < 15KB gzipped for entire library.

**Rules**:
- Tree-shakeable exports (no side effects)
- Minimal dependencies (prefer zero dependencies)
- Code split by platform when possible
- No large libraries for simple tasks (e.g., don't import lodash for one function)

**Monitoring**:
- Bundle size check in CI
- Size budget enforcement (build fails if exceeded)
- Report size impact in PR descriptions

---

### 8. API Simplicity

**Principle**: The API should be intuitive with zero configuration for basic use.

**Rules**:
- Required props are truly required (only `html` prop required)
- Optional props have sensible defaults
- Prop names follow React/React Native conventions
- TypeScript autocomplete provides all needed information

**API Design**:
- ✅ Good: `<HTMLText html={content} className="text-lg" />`
- ❌ Bad: `<HTMLText html={content} config={{ styles: { root: { fontSize: 18 } } }} />`

---

### 9. No Platform Leakage

**Principle**: Platform-specific code is isolated to adapters. Core logic is platform-agnostic.

**Rules**:
- Parser/sanitizer has zero platform-specific code
- HTMLText component uses platform detection to route to adapters
- Adapters are in separate files (native.tsx, web.tsx)
- Shared types are platform-agnostic

**Structure**:
```
src/
  core/          # Platform-agnostic
    parser.ts
    sanitizer.ts
  adapters/      # Platform-specific
    native.tsx
    web.tsx
  components/    # Routes to adapters
    HTMLText.tsx
```

---

### 10. Documentation as Code

**Principle**: Code is self-documenting. Comments explain "why", not "what".

**Rules**:
- JSDoc on all exported functions/components
- Prop interfaces have descriptions
- Complex algorithms have architectural comments
- No comments that restate the code

**Examples**:
- ✅ Good: `// Sanitize to prevent XSS attacks via script injection`
- ❌ Bad: `// Loop through array`

---

## Quality Gates (All Must Pass)

### Code Quality
- [ ] All tests passing (100% coverage for new code)
- [ ] ESLint passing with zero errors/warnings
- [ ] TypeScript compiler passing with zero errors
- [ ] Prettier formatting applied
- [ ] Bundle size under budget
- [ ] No ignore comments anywhere

### Testing
- [ ] Unit tests for all functions
- [ ] Integration tests for component composition
- [ ] Visual regression tests (snapshot tests)
- [ ] Accessibility tests (screen reader, keyboard navigation)
- [ ] Performance benchmarks met

### Documentation
- [ ] README with examples
- [ ] API reference complete
- [ ] Migration guide (if applicable)
- [ ] JSDoc on all exports

### Review
- [ ] Code review approved by team member
- [ ] Architecture review approved (for Specs 1-4)
- [ ] Security review for sanitization code (Spec 1)

---

## Technical Constraints

### Dependencies
- **Required**: react, react-native, react-native-web
- **Optional Peers**: nativewind, tailwindcss
- **Development**: jest, testing-library, typescript, eslint, prettier
- **Prohibited**: Any library that duplicates native functionality, large UI libraries, jQuery-like utilities

### Performance Targets
- Parse + render: < 16ms for 100-500 character HTML
- Re-render on prop change: < 8ms
- Memory: < 1MB for typical usage
- Bundle: < 15KB gzipped

### Browser Support (Web)
- Chrome/Edge: Last 2 versions
- Safari: Last 2 versions
- Firefox: Last 2 versions
- Mobile browsers: iOS Safari, Chrome Android

### React Native Support
- React Native >= 0.80
- iOS >= 13
- Android >= API 21 (5.0 Lollipop)

---

## Development Workflow

### Feature Development
1. Create feature branch from main
2. Run `/speckit.specify` with spec section
3. Review and `/speckit.clarify` if needed
4. Run `/speckit.plan` to generate design
5. Run `/speckit.tasks` to generate task list
6. Run `/speckit.analyze` to check consistency
7. Implement using TDD (red-green-refactor)
8. Create PR with spec/plan/tasks linked
9. Pass all quality gates
10. Merge to main

### Bug Fixes
1. Write failing test that reproduces bug
2. Verify test fails
3. Fix bug with minimal change
4. Verify test passes
5. Add regression test if needed
6. Create PR with test and fix

### Refactoring
1. Ensure 100% test coverage of code to refactor
2. Refactor while keeping tests green
3. No behavior changes
4. No test changes (unless removing redundant tests)
5. Create PR explaining refactoring rationale

---

## Code Style

### Naming Conventions
- **Components**: PascalCase (HTMLText, NativeAdapter)
- **Functions**: camelCase (parseHTML, sanitizeHTML)
- **Constants**: UPPER_SNAKE_CASE (DEFAULT_ALLOWED_TAGS)
- **Types**: PascalCase (HTMLTextProps, ParsedNode)
- **Files**: Match primary export (HTMLText.tsx, parser.ts)

### Self-Documenting Code
- Variable names describe content, not type
  - ✅ `sanitizedHTML`, `allowedTags`
  - ❌ `data`, `config`, `temp`
- Function names are verbs
  - ✅ `parseHTML`, `renderNode`, `sanitizeContent`
  - ❌ `html`, `node`, `content`

### Function Size
- Prefer small, focused functions (< 20 lines)
- Extract complexity into named helper functions
- One level of abstraction per function

---

## Security Requirements

### HTML Sanitization
- Allowlist approach (never blocklist)
- Remove all script tags and event handlers
- Validate all URLs (no javascript: protocol)
- Escape HTML entities properly
- Test against OWASP XSS vectors

### Dependencies
- Regular security audits (npm audit)
- No dependencies with known vulnerabilities
- Pin exact versions in package.json

---

## Forbidden Patterns

### ❌ Premature Abstraction
```typescript
// Don't create abstractions for hypothetical future needs
// Wait until you have 3 concrete use cases
```

### ❌ Feature Flags for Incomplete Features
```typescript
// Don't merge incomplete features behind flags
// Finish the feature before merging
```

### ❌ Backward Compatibility Hacks
```typescript
// Don't keep unused code "just in case"
// Delete unused exports, props, functions
```

### ❌ Any Without Justification
```typescript
// Don't use 'any' without documented reason
interface Props {
  data: any  // ❌ What is this?
}

interface Props {
  /**
   * Raw data from external API. Using 'any' because shape is dynamic
   * and validated at runtime by zod schema. Approved by: @reviewer
   */
  data: any  // ✅ Justified
}
```

---

## Platform-Specific Considerations

### Native (iOS/Android)
- Text must be child of Text (can't nest View in Text)
- Block elements require View wrapper
- Typography inherits from parent Text
- Hit areas must be minimum 44x44 points

### Web
- Use semantic HTML (strong, em, p, not div)
- CSS classes applied to HTML elements
- Respect user's browser text size preferences
- Support keyboard navigation

### react-native-web
- Leverage Text component for cross-platform consistency
- Don't fight react-native-web's rendering
- Trust react-native-web for style conversion

---

## Success Metrics

### Functionality
- [ ] All supported HTML tags render correctly
- [ ] className prop works on all platforms
- [ ] testID prop works for UI testing
- [ ] Accessibility props work everywhere

### Quality
- [ ] 100% test coverage
- [ ] Zero TypeScript errors
- [ ] Zero ESLint errors
- [ ] WCAG AA compliant

### Performance
- [ ] < 15KB gzipped bundle
- [ ] < 16ms render time
- [ ] Faster or equal to current solution

### Adoption
- [ ] Can replace current HTMLText in Figtree
- [ ] Migration completed with < 1 day effort
- [ ] No visual regressions in Figtree

---

## Amendment Process

This constitution can only be amended through:
1. Team discussion and consensus
2. Document the rationale
3. Update this file
4. Communicate to all team members

Individual specs cannot override the constitution. If a spec conflicts with this constitution, the constitution wins.

---

## Acknowledgments

This constitution inherits principles from:
- Figtree CLAUDE.md project guidelines
- React Native best practices
- WCAG accessibility guidelines
- Kent C. Dodds' Testing JavaScript principles
- Uncle Bob's Clean Code principles

When in doubt, refer to these sources for clarification.
