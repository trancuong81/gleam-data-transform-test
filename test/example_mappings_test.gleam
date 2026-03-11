import data_transform/example_mappings.{
  LpSignatoryFields, SourceFields, W9Fields,
}
import gleam/option.{Some}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

fn ds() {
  example_mappings.default_source()
}

// --- split_name tests ---

pub fn split_name_full_test() {
  let result = example_mappings.split_name("John Michael Smith")
  result.first_name |> should.equal("John")
  result.middle_name |> should.equal("Michael")
  result.last_name |> should.equal("Smith")
}

pub fn split_name_two_parts_test() {
  let result = example_mappings.split_name("Jane Doe")
  result.first_name |> should.equal("Jane")
  result.middle_name |> should.equal("")
  result.last_name |> should.equal("Doe")
}

pub fn split_name_empty_test() {
  let result = example_mappings.split_name("")
  result.first_name |> should.equal("")
  result.middle_name |> should.equal("")
  result.last_name |> should.equal("")
}

pub fn split_name_single_test() {
  let result = example_mappings.split_name("Madonna")
  result.first_name |> should.equal("Madonna")
  result.last_name |> should.equal("Madonna")
}

// --- transform tests ---

pub fn commitment_mapping_test() {
  let src =
    SourceFields(
      ..ds(),
      lp_signatory: Some(LpSignatoryFields(
        ..{
          let assert Some(lp) = ds().lp_signatory
          lp
        },
        commitment_amount: "1,000,000",
      )),
    )
  let target = example_mappings.transform(src)
  target.commitment_amount |> should.equal(1_000_000.0)
}

pub fn investor_name_prefers_aml_test() {
  let src =
    SourceFields(..ds(), aml_name: "AML Name", general_name: "General Name")
  let target = example_mappings.transform(src)
  target.investor_name |> should.equal("AML Name")
}

pub fn investor_name_falls_back_test() {
  let src =
    SourceFields(..ds(), aml_name: "", general_name: "General Name")
  let target = example_mappings.transform(src)
  target.investor_name |> should.equal("General Name")
}

pub fn regulated_status_yes_test() {
  let src =
    SourceFields(..ds(), regulated_keys: [
      "yes_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
    ])
  let target = example_mappings.transform(src)
  target.regulated_status |> should.equal("true")
}

pub fn regulated_status_no_test() {
  let src =
    SourceFields(..ds(), regulated_keys: [
      "no_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
    ])
  let target = example_mappings.transform(src)
  target.regulated_status |> should.equal("false")
}

pub fn international_supplements_test() {
  let src =
    SourceFields(..ds(), entity_intl_keys: [
      "none_entity_internationalsupplements_part1_duediligencequestionnaire",
    ])
  let target = example_mappings.transform(src)
  target.intl_supplements |> should.equal(["No Supplement"])
}

pub fn signer_name_split_test() {
  let src =
    SourceFields(
      ..ds(),
      lp_signatory: Some(LpSignatoryFields(
        commitment_amount: "5000000",
        individual_name: "",
        entity_name: "Catherine L Ziobro",
      )),
    )
  let target = example_mappings.transform(src)
  target.signer_first_name |> should.equal("Catherine")
  target.signer_middle_name |> should.equal("L")
  target.signer_last_name |> should.equal("Ziobro")
}

pub fn signer_name_prefers_individual_test() {
  let src =
    SourceFields(
      ..ds(),
      lp_signatory: Some(LpSignatoryFields(
        commitment_amount: "5000000",
        individual_name: "Jane Smith",
        entity_name: "Entity Auth",
      )),
    )
  let target = example_mappings.transform(src)
  target.signer_first_name |> should.equal("Jane")
}

pub fn w9_tin_type_ein_test() {
  let src =
    SourceFields(..ds(), w9: Some(W9Fields(ssn: "", ein: "", line2: "")))
  let target = example_mappings.transform(src)
  target.tin_type |> should.equal("EIN")
}

pub fn w9_tin_type_ssn_test() {
  let src =
    SourceFields(
      ..ds(),
      w9: Some(W9Fields(ssn: "123-45-6789", ein: "", line2: "")),
    )
  let target = example_mappings.transform(src)
  target.tin_type |> should.equal("SSN")
}

pub fn w9_tin_type_line2_present_test() {
  let src =
    SourceFields(
      ..ds(),
      w9: Some(W9Fields(ssn: "", ein: "", line2: "Some LLC")),
    )
  let target = example_mappings.transform(src)
  target.tin_type |> should.equal("")
}
