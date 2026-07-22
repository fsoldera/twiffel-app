# Writing style — generated prose

When an agent **generates text** (UI copy, store listings, marketing, privacy/legal
blurb text, nag/paywall strings, AI system/user prompts that produce user-visible
sentences, or similar prose):

```text
- Never use a double hyphen "--" or an em dash "—" as punctuation.
- Use a comma "," instead.
```

Examples:

```text
Bad:  Tap the box to spend one -- no logging, no charts.
Bad:  Tap the box to spend one — no logging, no charts.
Good: Tap the box to spend one, no logging, no charts.
```

This rule applies to **prose only**. It does not forbid:

- CLI / code flags (`--dart-define`, `--release`)
- Markdown horizontal rules (`---`)
- YAML / front matter separators
- Git commit ranges or similar technical syntax
