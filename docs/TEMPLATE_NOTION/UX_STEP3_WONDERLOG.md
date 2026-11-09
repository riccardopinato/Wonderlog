# Wonderlog Trip Planner — Step3 source integration

Product-approved pilot: one free/editable Journey with destination, period and optional plain-text description headings for stop ideas and packing. Entry: existing New Journey dialog > Create from a model > select text sections > review > confirm.

Uses `WonderlogRepository.createJourney`; the premium limit is rechecked just before writing. The confirmation cannot execute twice concurrently in the same dialog. No budget, expense, booking, routing, structured packing entity, new migration, billing, Google API, cloud or map writes. Full cross-session exactly-once guarantees depend on the canonical repository and remain unproven in this scoped pilot.

Test description builder and localized UI (en/it/es/fr/de/pt), 360dp/large screen, invalid inputs, back/close during writing, retry failures, free limit and account switch. Do not infer real-device performance or production readiness from an HTML mock-up or a green source gate.

Factory baseline d4ed1185d36d419228fba6b57a979cde308bd321.
