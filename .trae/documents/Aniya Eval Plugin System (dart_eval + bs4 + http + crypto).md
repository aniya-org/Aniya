## Overview
- Introduce a new extension ecosystem powered by `dart_eval` where plugins live as persisted source code strings and run inside a sandboxed runtime with network enabled.
- Bind selected APIs from `http`, `crypto`, and `beautiful_soup_dart` so plugin code can fetch, parse and process content.
- Integrate this ecosystem into the existing extension manager, displayed in its own tabs and labeled "Aniya" to distinguish from Mangayomi/Aniyomi/CloudStream/LnReader.

## New Extension Type
- Add `ExtensionType.aniya` for the eval-based ecosystem in:
  - `lib/core/domain/entities/extension_entity.dart` (maps to app enums)
  - `deps/DartotsuExtensionBridge/lib/ExtensionManager.dart` (bridge routing)
- Create `AniyaEvalExtensions` manager (parallel to existing managers) exposing:
  - Installed/available lists by `ItemType`
  - `installSource` / `uninstallSource` / `updateSource`
  - `fetchAvailable*Extensions()` (optional; may be empty initially)
- Create `AniyaEvalSourceMethods` implementing the same shape as bridge methods (`search`, `getDetail`, episode/chapter listing, `getVideoList`), but internally dispatching into the `dart_eval` runtime for a given plugin.

## Plugin Base & Binding
- Define a base interface for plugins, e.g. `abstract class AniyaPluginBase` with:
  - Metadata: `id`, `name`, `version`, `language`, `itemType`, optional `url` (for updates)
  - Methods: `search(String query, int page)`, `getDetail(String mediaId)`, `getEpisodes(String mediaId)`, `getVideoList(String episodeId)`
- Annotate with `@Bind(bridge: true)` from `eval_annotation` to generate bridge types that can be extended from interpreter code.
- Provide a helper `EvalPluginApi` passed into runtime with bound capabilities:
  - `http.get(url, {headers})` / `http.post(...)`
  - `crypto` helpers (e.g., `sha256Hex(String)`)
  - `HtmlSoup.parse(String)` minimal wrapper over `BeautifulSoup` with a small set of methods (`find`, `findAll`, `text`, `outerHtml`) to keep binding scope tight.
- Generate bindings using the `dart_eval` binding generator (wrapper/bridge and a `EvalPlugin` that registers the bindings):
  - `dart run dart_eval:bind` (produces `eval_plugin.dart`, bridge classes, and `configureForRuntime(Runtime)`)

## Runtime & Permissions
- On load or install:
  - Compile source string via `Compiler.compile({'plugin:main.dart': src})` or use `eval()` for quick prototypes.
  - Create `Runtime.ofProgram(program)` or `Runtime(bytecode)`.
- Enable network access appropriately:
  - Grant per-plugin domains when available: `runtime.grant(NetworkPermission.url('example.com'))`
  - Fallback (development): `runtime.grant(NetworkPermission.any)`
- Register generated plugin bindings: `EvalPlugin.configureForRuntime(runtime)` (from binding generator), plus custom wrappers.
- Optional: Add `@AssertPermission` checks in bindings for sensitive calls (e.g., file system, process), leaving those disabled.

## Storage & Lifecycle
- Persist plugin source code strings and metadata via Hive:
  - New box, e.g., `Box('aniyaEvalPlugins')`, entries keyed by `pluginId` and store `{ id, name, version, language, itemType, url?, sourceCode, compiledBytecode? }`.
  - Store compiled bytecode (optional) for faster subsequent loads (`program.write()` and rehydrate with `Runtime(bytecode)`).
- Install:
  - Create `Source` record (bridge model) with `extensionType: ExtensionType.aniya` and `itemType`, mark as installed.
  - Persist the plugin source + metadata.
- Update:
  - If `url` set, fetch latest source via native `http` client, validate (version bump, optional signature), recompile, persist.
- Uninstall:
  - Remove persisted data and Source entry, clean runtime cache.

## Manager Integration
- Wire into extension aggregation:
  - Extend `getSupportedExtensions` and `ExtensionType.getManager()` to include `ExtensionType.aniya` mapped to `AniyaEvalExtensions`.
  - Ensure `ExtensionMethodsExtension` maps `ExtensionType.aniya` to `AniyaEvalSourceMethods`.
- Map to app models in `ExtensionsController`:
  - Update type mapping to include `domain.ExtensionType.aniya` when bridge `ExtensionType.aniya` is encountered.
  - Include installed/available lists for this type in `_sortAllExtensions()`.

## UI Integration
- Extension screen tabs: add an "Aniya" set (Installed/Available) alongside Anime/Manga/Novel/CloudStream:
  - Show installed and available Aniya eval plugins filtered by `ItemType`.
  - Badges reflect counts; items display name, version, language, and a clear "Aniya" tag.
- Add a plugin editor / add flow:
  - "Add Aniya Plugin" button opens a modal with fields: `id`, `name`, `language`, `itemType`, `version`, optional `url`, and a multiline code editor for source string.
  - Actions: Install (compile + grant permissions + save), Update (fetch from `url`), Uninstall.
- Extension manager tabs separation:
  - Keep existing bridge extensions under their repos.
  - Place Aniya eval plugins under their own section and label list items with source type "Aniya".

## Example Plugin Code (Interpreter)
- Minimal skeleton users can paste into the editor:
  - Imports: `import 'package:plugin_api/api.dart';`
  - Class: `class MyPlugin extends AniyaPluginBase { /* override methods */ }`
  - Use `api.http.get(...)`, `api.soup.parse(html).findAll(...)`, `api.crypto.sha256Hex(...)`.
- Execution entrypoint:
  - `void main() { /* optional setup */ }`
- Runtime call:
  - `runtime.executeLib('package:plugin:main.dart', 'main')` then resolve plugin instance via a factory function or known entry symbol.

## Security & Compliance
- Network: prefer domain-scoped `NetworkPermission.url('domain')` per plugin; store allowed domains in metadata and enforce via `@AssertPermission`.
- No file/process permissions granted.
- Add try/catch around all runtime calls; surface errors to UI with a safe message.
- Consider App Store restrictions: use EVC bytecode for updates; vet plugins; show author/version.

## Testing & Verification
- Unit tests for bindings:
  - Verify `http.get` wrapper returns expected data inside eval.
  - Verify `HtmlSoup.parse(...).find(...)` works through bindings.
  - Verify `crypto` helpers compute expected digests.
- Integration tests:
  - Install a sample plugin from a pasted string; run `search()`; parse sample HTML; ensure results render in lists.
- Desktop/Android checks:
  - Validate `NetworkPermission` grants take effect and are revocable.

## References
- dart_eval docs: https://pub.dev/packages/dart_eval (permissions, `@Bind`, bridge mode)
- dart_eval API: https://pub.dev/documentation/dart_eval/latest/dart_eval/
- Binding generator changelog: https://pub.dev/packages/dart_eval/changelog
- beautiful_soup_dart docs: https://pub.dev/documentation/beautiful_soup_dart/latest/

## Deliverables
- New `Aniya` ecosystem type and manager with runtime glue.
- Base plugin API (bridge) with bound `http`, `crypto`, and minimal `BeautifulSoup` helpers.
- Hive-backed persistence of source strings and optional bytecode.
- Extension manager UI updates with separate Aniya tabs and plugin editor.
- Sample plugin template and tests.
