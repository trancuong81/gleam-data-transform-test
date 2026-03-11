# gleam-data-transform

A Gleam (JavaScript target) project that performs field-level data transformations using protobuf-generated types. Source and target table schemas are defined in `.proto` files, and the transformation logic maps fields between them with type-safe Gleam code.

## Prerequisites

- [Gleam](https://gleam.run/getting-started/installing/) v1.14+
- [Node.js](https://nodejs.org/) (for the JavaScript target runtime)

## Setup

```bash
# Install dependencies
gleam deps download

# Build the project
gleam build
```

## Running Tests

```bash
gleam test
```

This runs all 33 tests across 8 test suites covering JSON path navigation, transform utilities, mappings, example field transforms, schema loading, protobuf roundtrips, and end-to-end integration.

## Running the CLI

```bash
gleam run -m data_transform/main -- <path-to-values.json>
```

Reads a source JSON file, applies all field transforms, and prints the transformed JSON to stdout.

Example:

```bash
gleam run -m data_transform/main -- test/fixtures/values.json
```

## Repository Structure

```
gleam-data-transform/
├── gleam.toml                          # Project config (target: javascript)
├── manifest.toml                       # Locked dependency versions
├── src/
│   ├── data_transform.gleam            # Package entry point
│   ├── codegen.gleam                   # Protozoa protobuf codegen script
│   └── data_transform/
│       ├── proto/                      # Protobuf-generated Gleam types
│       │   ├── data_types.gleam        # StringType, NumberType, MoneyType, etc.
│       │   ├── source_table.gleam      # SourceTableFieldsMap, LpSignatoryType, W9Type
│       │   ├── target_table.gleam      # TargetTableFieldsMap
│       │   ├── struct.gleam            # google.protobuf.Struct (manually maintained)
│       │   └── test_simple.gleam       # Simple proto for codegen smoke tests
│       ├── json_value.gleam            # Custom JSON value type + parser/serializer
│       ├── json_path.gleam             # JSON navigation (get/set by key path)
│       ├── transform_utils.gleam       # Collection helpers (group_by, merge_by, deep_merge)
│       ├── mappings.gleam              # Generic mapping engine (textbox, checkbox, custom)
│       ├── example_mappings.gleam      # 6 concrete field transforms
│       ├── schema.gleam                # Schema loading from JSON constants files
│       ├── main.gleam                  # CLI entry point (JSON I/O + transform pipeline)
│       └── main_ffi.mjs               # Node.js FFI (file read, CLI args, stdout)
├── proto/
│   ├── data_types.proto                # Shared field types (String, Number, Money, etc.)
│   ├── table_schema.proto              # Table schema envelope types
│   ├── data_types_constants.json       # Type metadata constants (47 types)
│   └── tables/
│       ├── source_table.proto          # Source table schema
│       ├── target_table.proto          # Target table schema
│       ├── source_table_constants.json # Source field metadata
│       └── target_table_constants.json # Target field metadata
├── test/
│   ├── data_transform_test.gleam       # Test runner entry point
│   ├── json_path_test.gleam            # JSON path navigation tests (4)
│   ├── transform_utils_test.gleam      # Collection helper tests (6)
│   ├── mappings_test.gleam             # Mapping engine tests (2)
│   ├── example_mappings_test.gleam     # Field transform tests (15)
│   ├── schema_test.gleam               # Schema loading tests (2)
│   ├── protobuf_test.gleam             # Protobuf roundtrip tests (2)
│   ├── integration_test.gleam          # End-to-end pipeline test (1)
│   └── fixtures/
│       ├── values.json                 # Source fixture
│       └── transformed_values.json     # Expected output fixture
└── build/                              # Build artifacts (gitignored)
```

## Main Components

### Proto-Generated Types

The `src/data_transform/proto/` directory contains Gleam types generated from `.proto` schemas by [protozoa](https://hexdocs.pm/protozoa/). These define the structure of source and target data:

- **`data_types.gleam`** — Shared field types: `StringType`, `NumberType`, `MoneyType`, `MoneySubFields`, `RadioGroupType`, `MultipleCheckboxType`, and compound container types.
- **`source_table.gleam`** — `SourceTableFieldsMap` with all source fields (LP signatory, investor names, regulated status, international supplements, W9). Includes sub-field types `LpSignatoryType`/`LpSignatoryFields` and `W9Type`/`W9Fields`.
- **`target_table.gleam`** — `TargetTableFieldsMap` with all target fields (commitment, investor name, signer name parts, regulated status, international supplements, TIN type).

### Example Mappings (`example_mappings.gleam`)

Six concrete field transforms that map `SourceTableFieldsMap` to `TargetTableFieldsMap`:

| Transform | Description |
|-----------|-------------|
| `map_commitment` | Parses comma-separated amount string to float |
| `map_investor_name` | Picks first non-empty name (AML questionnaire > general info) |
| `map_regulated_status` | Maps checkbox keys to "true"/"false" radio selection |
| `map_international_supplements` | Maps checkbox keys to supplement labels, deduplicates |
| `map_signer_name` | Picks individual > entity name, splits into first/middle/last |
| `map_w9_tin_type` | Determines SSN vs EIN based on which W9 fields are populated |

Also includes the `split_name` helper that parses a full name string into `NameParts(first_name, middle_name, last_name)`.

### CLI Entry Point (`main.gleam`)

- `json_to_source(json)` — Converts parsed JSON into `SourceTableFieldsMap`
- `target_to_json(target)` — Converts `TargetTableFieldsMap` back to JSON
- `main()` — Reads input file path from CLI args, runs the full pipeline, writes JSON to stdout

Uses Node.js FFI (`main_ffi.mjs`) for file I/O and CLI argument access.

### JSON Value (`json_value.gleam`)

Custom JSON value type (`JsonValue`) with variants: `JsonNull`, `JsonBool`, `JsonInt`, `JsonFloat`, `JsonString`, `JsonArray`, `JsonObject`. Provides `parse()`, `to_string()`, `as_object()`, `as_string()`, and other accessors.

### Supporting Modules

- **`json_path.gleam`** — Navigate and modify nested JSON by key paths (`get_path`, `set_path`, typed extractors).
- **`transform_utils.gleam`** — Collection helpers: `group_by`, `merge_by`, `map_values`, `deep_merge`.
- **`mappings.gleam`** — Generic mapping engine with `textbox_mapping`, `checkbox_mapping`, `custom_mapping`, and `apply_mapping`/`transform_all`.
- **`schema.gleam`** — Loads type metadata from JSON constants files. Includes `snake_to_camel` key conversion.

## Protobuf Codegen

Types are generated from `.proto` files using [protozoa](https://hexdocs.pm/protozoa/) v2.0.3.

To regenerate the Gleam types from proto schemas:

```bash
gleam run -m codegen
```

This processes all `.proto` files in the `proto/` directory using protozoa's import resolver and outputs `.gleam` files to `src/data_transform/proto/`.

**After regeneration, manual fixes are required** — see Known Issues below.

## Known Issues

### Protozoa Exponential Codegen on Large Oneofs

Protozoa has a codegen bug where `oneof` fields with many variants cause exponential O(2^N) code generation. The original proto schemas had:

- `NonCustomFieldValue` — a 21-variant oneof in `data_types.proto`
- `SingleFieldType` — a 22-variant oneof in `table_schema.proto`

Both crashed protozoa during codegen.

**Workaround:** These large oneofs were replaced with `google.protobuf.Struct`:

- `NonCustomFieldValue` was deleted entirely; `CustomCompoundType.value_sub_fields` now uses `map<string, google.protobuf.Struct>`
- `SingleFieldType` was simplified to contain `google.protobuf.Struct value` + `string type_id` + `string label`

This works because protozoa has hardcoded well-known type support for `google.protobuf.Struct`, bypassing the buggy generic codegen path. The tradeoff is that these fields lose their typed oneof variants and instead use `Dict(String, Value)` in Gleam.

### Manual Fixes After Codegen

After running `gleam run -m codegen`, three manual fixes are needed in the generated files:

1. **Cross-file imports** — Protozoa doesn't generate imports between its own output files. You must manually add:
   - `import data_transform/proto/struct.{type Struct, struct_decoder}` in `data_types.gleam`
   - `import data_transform/proto/data_types.{...}` in `source_table.gleam` and `target_table.gleam` (importing all referenced types and removing `data_types.` prefixes from usage sites)

2. **Duplicate definitions in `struct.gleam`** — Protozoa generates both a hardcoded well-known type version AND a generic codegen version of `Struct`/`Value`/`ValueKind`. The file must be manually cleaned to keep only one set of definitions. The current `struct.gleam` is manually maintained with stubbed encode/decode functions.

3. **Unused imports** — Generated files may have unused imports that produce warnings. Remove them for a clean build.
