import data_transform/example_mappings
import data_transform/json_value
import data_transform/main
import gleeunit
import gleeunit/should
import simplifile

pub fn main() {
  gleeunit.main()
}

pub fn end_to_end_pipeline_test() {
  // Read source fixture
  let assert Ok(source_content) = simplifile.read("test/fixtures/values.json")
  let assert Ok(source_json) = json_value.parse(source_content)

  // Read expected output
  let assert Ok(expected_content) =
    simplifile.read("test/fixtures/transformed_values.json")
  let assert Ok(expected_json) = json_value.parse(expected_content)

  // Run the transformation pipeline
  let source = main.json_to_source(source_json)
  let target = example_mappings.transform(source)
  let result_json = main.target_to_json(target)

  // Compare JSON output
  json_value.to_string(result_json)
  |> should.equal(json_value.to_string(expected_json))
}
