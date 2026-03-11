import data_transform/proto/data_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn string_type_binary_roundtrip_test() {
  let original =
    data_types.StringType(
      type_id: "Ssn",
      value: "123-45-6789",
      regex: "^\\d{3}-\\d{2}-\\d{4}$",
      format_patterns: ["000-00-0000"],
    )
  let encoded = data_types.encode_stringtype(original)
  let assert Ok(decoded) = data_types.decode_stringtype(encoded)
  decoded.type_id |> should.equal("Ssn")
  decoded.value |> should.equal("123-45-6789")
  decoded.regex |> should.equal("^\\d{3}-\\d{2}-\\d{4}$")
  decoded.format_patterns |> should.equal(["000-00-0000"])
}

pub fn multiple_checkbox_roundtrip_test() {
  let original =
    data_types.MultipleCheckboxType(
      type_id: "MultipleCheckbox",
      selected_keys: ["opt1", "opt3"],
      all_option_keys_in_order: ["opt1", "opt2", "opt3"],
      all_option_labels_in_order: ["Option 1", "Option 2", "Option 3"],
    )
  let encoded = data_types.encode_multiplecheckboxtype(original)
  let assert Ok(decoded) = data_types.decode_multiplecheckboxtype(encoded)
  decoded.selected_keys |> should.equal(["opt1", "opt3"])
  decoded.type_id |> should.equal("MultipleCheckbox")
}
