import gleam/io
import protozoa/internal/codegen
import protozoa/parser
import simplifile

pub fn main() {
  let proto_path = "src/data_transform/proto/test_simple.proto"
  case simplifile.read(proto_path) {
    Error(_) -> io.println("Failed to read " <> proto_path)
    Ok(content) -> {
      case parser.parse(content) {
        Error(_err) -> {
          io.println("Parse error")
        }
        Ok(proto_file) -> {
          io.println("Parsed successfully!")
          let code = codegen.generate_simple_for_testing(proto_file)
          case simplifile.write("src/data_transform/proto/test_simple.gleam", code) {
            Ok(_) -> io.println("Generated: data_types.gleam")
            Error(_) -> io.println("Failed to write output")
          }
        }
      }
    }
  }
}
