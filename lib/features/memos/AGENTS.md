Memos domain rules

- New memo-domain code should live under this folder instead of adding more files to top-level `screens/`, `widgets/`, `services/`, or `models/`.
- Keep screen widgets thin. Move memo-specific calculations, filtering, ordering, and state helpers into domain services or models when they grow beyond local UI glue.
- Preserve raw memo ordering and favorite/trash semantics. Changes that affect stored data shape, backup JSON, or restore behavior need explicit tests.
- Do not migrate existing files into this domain as part of a small feature unless the task explicitly asks for migration.
- If a new file imports more than two legacy top-level services, add a note in this folder README explaining whether that dependency should stay shared or become domain-owned later.
