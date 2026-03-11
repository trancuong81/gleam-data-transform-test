import data_transform/schema
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn load_data_type_constants_test() {
  let assert Ok(constants) = schema.load_data_type_constants()
  // Verify Ssn has correct regex
  let ssn = schema.find_type_constants(constants, "Ssn")
  option.is_some(ssn) |> should.be_true
  let assert option.Some(ssn_tc) = ssn
  schema.has_regex(ssn_tc) |> should.be_true
  // Verify total count
  schema.type_count(constants) |> should.equal(47)
}

pub fn snake_to_camel_test() {
  schema.snake_to_camel("hello_world") |> should.equal("helloWorld")
  schema.snake_to_camel("asa_commitment_amount")
  |> should.equal("asaCommitmentAmount")
  schema.snake_to_camel("simple") |> should.equal("simple")
}
