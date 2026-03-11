import gleam/io
import gleam/list
import gleam/result
import protozoa/internal/codegen
import protozoa/internal/import_resolver
import protozoa/parser

const proto_dir = "src/data_transform/proto"

// Leaf proto files — data_types.proto and table_schema.proto resolved via imports
const proto_files = [
  "tables/source_table.proto", "tables/target_table.proto",
]

pub fn main() {
  let resolver =
    import_resolver.new()
    |> import_resolver.with_search_paths([proto_dir, "."])

  // Resolve all proto files (handles imports between them)
  let resolved =
    list.try_fold(proto_files, resolver, fn(acc_resolver, file) {
      let full_path = proto_dir <> "/" <> file
      import_resolver.resolve_imports(acc_resolver, full_path)
      |> result.map(fn(pair) { pair.1 })
      |> result.map_error(fn(e) { import_resolver.describe_error(e) })
    })

  case resolved {
    Error(err) -> io.println("Error resolving imports: " <> err)
    Ok(final_resolver) -> {
      let registry = import_resolver.get_type_registry(final_resolver)
      let loaded = import_resolver.get_all_loaded_files(final_resolver)

      io.println("Loaded files:")
      list.each(loaded, fn(entry) { io.println("  " <> entry.0) })

      // Build Path list from ALL loaded files (including resolved imports)
      let paths =
        list.map(loaded, fn(entry) {
          parser.Path(path: entry.0, content: entry.1)
        })

      case codegen.generate_with_imports(paths, registry, proto_dir) {
        Ok(generated) -> {
          list.each(generated, fn(entry) {
            io.println("Generated: " <> entry.0)
          })
          io.println("Code generation complete!")
        }
        Error(err) -> io.println("Code generation error: " <> err)
      }
    }
  }
}
