# Cross-Platform HTML Renderer - Multi-Spec Project Structure

## Overview

This project will be broken down into multiple SpecKit specifications, each covering a distinct architectural component or feature set. This approach allows for:

- Parallel development of independent components
- Clear scope boundaries for each specification
- Incremental delivery and testing
- Easier code review and validation

## Specification Breakdown

### Spec 1: Foundation - Parser & Sanitizer
**Scope**: HTML parsing and sanitization core
**Deliverables**:
- HTML string to AST parser
- Allowlist-based HTML sanitizer
- AST type definitions
- Sanitization configuration API
- Comprehensive test suite for edge cases

**Dependencies**: None

**Success Criteria**:
- Parses all supported HTML tags correctly
- Sanitizes malicious/unsupported content
- 100% test coverage
- < 5KB gzipped

---

### Spec 2: Native Renderer - Text Tree Adapter
**Scope**: Convert HTML AST to React Native Text/View components
**Deliverables**:
- AST-to-component converter for native platform
- Text-based tree structure (Text children of Text where possible)
- View fallback for block elements
- Style inheritance from parent Text components
- Platform detection utilities

**Dependencies**: Spec 1 (Parser & Sanitizer)

**Success Criteria**:
- All inline tags render as nested Text components
- Block tags render with View wrappers
- Inherits typography from parent context
- Visual snapshot tests pass
- Works on iOS and Android

---

### Spec 3: Web Renderer - Semantic HTML Adapter
**Scope**: Convert HTML AST to semantic HTML via react-native-web
**Deliverables**:
- AST-to-component converter for web platform
- Semantic HTML output (p, strong, em, etc.)
- react-native-web Text component integration
- Style/className passthrough to HTML elements

**Dependencies**: Spec 1 (Parser & Sanitizer)

**Success Criteria**:
- Outputs valid semantic HTML
- CSS classes applied correctly
- Text styles converted to CSS
- Renders identically to native in browser
- Accessibility attributes preserved

---

### Spec 4: Core Component - HTMLText API
**Scope**: Public API and component interface
**Deliverables**:
- HTMLText component with unified API
- Platform routing (native vs web renderer)
- Props interface (html, className, style, testID, etc.)
- Default configuration and sensible fallbacks
- TypeScript type exports

**Dependencies**: Spec 2 (Native Renderer), Spec 3 (Web Renderer)

**Success Criteria**:
- Single import works on all platforms
- All props properly typed
- Renders correctly in Figtree test app
- Documentation complete
- Migration guide from old HTMLText

---

### Spec 5: Styling Integration - NativeWind Support
**Scope**: First-class NativeWind/Tailwind integration
**Deliverables**:
- className prop support on native
- cssInterop configuration for NativeWind
- Tag-specific style override API (tagStyles prop)
- Style inheritance and merging logic
- Tailwind class resolution

**Dependencies**: Spec 4 (Core Component)

**Success Criteria**:
- className prop works identically on native and web
- NativeWind classes resolve correctly
- Tag styles can be overridden via props
- Style precedence is predictable
- Works with dark mode / color scheme

---

### Spec 6: Advanced Features - Links & Lists
**Scope**: Complex HTML element support
**Deliverables**:
- Link (`<a>`) rendering with onLinkPress callback
- List rendering (`<ul>`, `<ol>`, `<li>`)
- Nested list support
- Link accessibility (role, label)
- List item markers/bullets

**Dependencies**: Spec 4 (Core Component)

**Success Criteria**:
- Links are tappable with proper hit areas
- Lists render with correct indentation
- Nested lists work up to 3 levels
- Screen reader announces links and lists
- Visual parity between platforms

---

### Spec 7: Polish & Performance - Optimization
**Scope**: Performance optimization and final polish
**Deliverables**:
- Memoization of parsed AST
- Bundle size optimization
- Performance benchmarks vs current solution
- numberOfLines truncation support
- Accessibility audit and fixes

**Dependencies**: All previous specs

**Success Criteria**:
- < 15KB gzipped bundle size
- < 16ms render time for typical content
- No unnecessary re-renders
- WCAG AA compliance
- Passes Figtree integration tests

---

## Dependency Graph

```
Spec 1: Parser & Sanitizer
    ├── Spec 2: Native Renderer
    │       └── Spec 4: Core Component
    │               ├── Spec 5: NativeWind Support
    │               ├── Spec 6: Advanced Features
    │               └── Spec 7: Polish & Performance
    └── Spec 3: Web Renderer
            └── Spec 4: Core Component (see above)
```

## Development Workflow

### Sequential Specs (must complete in order)
1. Spec 1 → Spec 2 → Spec 4 (Native path)
2. Spec 1 → Spec 3 → Spec 4 (Web path)
3. Spec 4 → Spec 5 → Spec 7 (Enhancement path)

### Parallel Specs (can develop concurrently)
- Spec 2 and Spec 3 (after Spec 1 completes)
- Spec 5 and Spec 6 (after Spec 4 completes)

## Repository Structure

```
packages/
  cross-platform-html-renderer/
    src/
      core/
        parser.ts          # Spec 1
        sanitizer.ts       # Spec 1
        types.ts           # Spec 1
      adapters/
        native.tsx         # Spec 2
        web.tsx            # Spec 3
      components/
        HTMLText.tsx       # Spec 4
        HTMLText.web.tsx   # Spec 3
      styling/
        nativewind.ts      # Spec 5
        tagStyles.ts       # Spec 5
      features/
        links.tsx          # Spec 6
        lists.tsx          # Spec 6
      __tests__/
        parser.test.ts
        native.test.tsx
        web.test.tsx
        integration.test.tsx
    package.json
    tsconfig.json
    README.md
```

## SpecKit Workflow per Spec

For each specification:

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/html-renderer-spec-N
   ```

2. **Initialize Spec**
   ```bash
   /speckit.specify
   ```
   - Provide the spec-specific section from this document
   - SpecKit generates detailed spec.md

3. **Review & Clarify**
   ```bash
   /speckit.clarify
   ```
   - Answer any ambiguities
   - Refine requirements

4. **Generate Implementation Plan**
   ```bash
   /speckit.plan
   ```
   - SpecKit creates plan.md with design decisions

5. **Generate Tasks**
   ```bash
   /speckit.tasks
   ```
   - SpecKit creates tasks.md with ordered implementation steps

6. **Analyze for Quality**
   ```bash
   /speckit.analyze
   ```
   - Cross-artifact consistency check

7. **Execute Implementation**
   ```bash
   /speckit.implement
   ```
   - Follow TDD workflow (red-green-refactor)
   - Complete all tasks from tasks.md

8. **Create Pull Request**
   - One PR per spec
   - Include spec.md, plan.md, tasks.md in PR description
   - Link to this project structure document

## Integration Testing

After each spec completes:

1. **Unit Tests**: Verify spec-specific functionality
2. **Integration Tests**: Verify interaction with completed specs
3. **Visual Tests**: Snapshot testing for rendering specs
4. **Performance Tests**: Benchmark render times
5. **Figtree Integration**: Test in actual app context

## Quality Gates

Each spec must pass before moving to next:

- ✅ All unit tests passing (100% coverage for new code)
- ✅ All integration tests passing
- ✅ ESLint and TypeScript checks passing (no errors, no ignore comments)
- ✅ Visual regression tests passing (for rendering specs)
- ✅ Bundle size within target (< 15KB total when all specs complete)
- ✅ Performance benchmarks met
- ✅ Code review approved
- ✅ Documentation updated

## Rollout Strategy

1. **Specs 1-4**: Core functionality - must all complete before any production use
2. **Spec 5**: NativeWind support - can ship without if needed, but recommended
3. **Spec 6**: Advanced features - can ship incrementally
4. **Spec 7**: Polish - can ship incrementally

**Minimum Viable Product**: Specs 1-4 complete
**Recommended Initial Release**: Specs 1-5 complete
**Full Release**: All specs complete

## Communication

- **Spec Assignment**: Document who owns each spec
- **Blockers**: Report in daily standup if blocked on dependency spec
- **Architecture Changes**: Discuss in team sync if spec reveals need for changes to other specs
- **Cross-Spec Impacts**: Tag other spec owners in PRs that might affect their work

## Timeline Estimate

| Spec | Complexity | Estimated Duration | Dependencies |
|------|-----------|-------------------|--------------|
| 1 | Medium | 3-5 days | None |
| 2 | High | 5-7 days | Spec 1 |
| 3 | Medium | 4-6 days | Spec 1 |
| 4 | Low | 2-3 days | Specs 2, 3 |
| 5 | Medium | 4-5 days | Spec 4 |
| 6 | Medium | 5-7 days | Spec 4 |
| 7 | Low | 2-3 days | All |

**Total (sequential)**: ~25-36 days
**Total (with parallelization)**: ~18-25 days

## Notes

- Each spec is independently testable and reviewable
- Later specs can refine earlier specs if needed (open new spec document)
- Constitution applies to all specs equally
- TDD is mandatory for all implementation work
- No code is merged until spec is 100% complete
