# Tests

`smoke.lua` is a **mocked-runtime** integration test. It uses fake `Drawing`, input, Roblox services and workspace globals to exercise the library without a Roblox client.

Run from the repository root using `lua tests/smoke.lua` (or an equivalent Lua interpreter/launcher).

The test deliberately makes **no network requests** and writes only to its in-memory file stub. The standard Lua runtime can run it after loading the test file. It is only an early confidence check; UI alignment, Matcha API compatibility, live mouse wheel behavior, and native input capture still require validation in Matcha.

On this build environment, the test was executed against the system Lua 5.4 shared library using a small standalone runner; no Lua CLI was pre-installed.
