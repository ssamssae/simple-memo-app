# Feature Domains

This directory is the pilot home for domain-based Flutter code.

The existing app still has legacy type-based folders such as `screens/`,
`services/`, `models/`, and `widgets/`. Do not move that code just to satisfy
this structure. New feature work should start in a domain folder here when the
change is naturally owned by one product area.

Expected shape:

```
lib/features/
  memos/
    README.md
    AGENTS.md
    screens/
    widgets/
    services/
    models/
```

Rules:

- Keep domain code close to the feature it serves.
- Preserve simple imports and avoid barrel files unless a domain grows enough to need one.
- Shared app-wide services can stay in the existing top-level folders until a separate migration task exists.
- Each domain folder should document ownership boundaries and local agent rules.
