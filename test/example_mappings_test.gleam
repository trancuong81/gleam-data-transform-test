import data_transform/example_mappings.{str}
import data_transform/proto/data_types.{MultipleCheckboxType}
import data_transform/proto/source_table.{
  LpSignatoryFields, LpSignatoryType, SourceTableFieldsMap, W9Fields, W9Type,
}
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
    SourceTableFieldsMap(
      ..ds(),
      lp_signatory: LpSignatoryType(
        ..ds().lp_signatory,
        value_sub_fields: LpSignatoryFields(
          ..ds().lp_signatory.value_sub_fields,
          asa_commitment_amount: str("1,000,000"),
        ),
      ),
    )
  let target = example_mappings.transform(src)
  target.sf_agreement_null_commitment_c.value_sub_fields.amount.value
  |> should.equal(1_000_000.0)
}

pub fn investor_name_prefers_aml_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      asa_fullname_investorname_amlquestionnaire: str("AML Name"),
      asa_fullname_investorname_generalinfo1: str("General Name"),
    )
  let target = example_mappings.transform(src)
  target.sf_account_subscription_investor_name.value
  |> should.equal("AML Name")
}

pub fn investor_name_falls_back_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      asa_fullname_investorname_amlquestionnaire: str(""),
      asa_fullname_investorname_generalinfo1: str("General Name"),
    )
  let target = example_mappings.transform(src)
  target.sf_account_subscription_investor_name.value
  |> should.equal("General Name")
}

pub fn regulated_status_yes_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      luxsentity_regulatedstatus_part2_duediligencequestionnaire: MultipleCheckboxType(
        ..ds().luxsentity_regulatedstatus_part2_duediligencequestionnaire,
        selected_keys: [
          "yes_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
        ],
      ),
    )
  let target = example_mappings.transform(src)
  target
    .sf_account_subscription_investor_wlc_publicly_listed_on_a_stock_exchange_c
    .selected_key
  |> should.equal("true")
}

pub fn regulated_status_no_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      luxsentity_regulatedstatus_part2_duediligencequestionnaire: MultipleCheckboxType(
        ..ds().luxsentity_regulatedstatus_part2_duediligencequestionnaire,
        selected_keys: [
          "no_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
        ],
      ),
    )
  let target = example_mappings.transform(src)
  target
    .sf_account_subscription_investor_wlc_publicly_listed_on_a_stock_exchange_c
    .selected_key
  |> should.equal("false")
}

pub fn international_supplements_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      entity_internationalsupplements_part1_duediligencequestionnaire: MultipleCheckboxType(
        ..ds()
          .entity_internationalsupplements_part1_duediligencequestionnaire,
        selected_keys: [
          "none_entity_internationalsupplements_part1_duediligencequestionnaire",
        ],
      ),
    )
  let target = example_mappings.transform(src)
  target
    .sf_agreement_null_wlc_international_supplements_c
    .selected_keys
  |> should.equal(["No Supplement"])
}

pub fn signer_name_split_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      lp_signatory: LpSignatoryType(
        ..ds().lp_signatory,
        value_sub_fields: LpSignatoryFields(
          asa_commitment_amount: str("5000000"),
          individual_subscribername_signaturepage: str(""),
          entity_authorizedname_signaturepage: str("Catherine L Ziobro"),
        ),
      ),
    )
  let target = example_mappings.transform(src)
  target.sf_agreement_null_signer_first_name.value
  |> should.equal("Catherine")
  target.sf_agreement_null_signer_middle_name.value |> should.equal("L")
  target.sf_agreement_null_signer_last_name.value |> should.equal("Ziobro")
}

pub fn signer_name_prefers_individual_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      lp_signatory: LpSignatoryType(
        ..ds().lp_signatory,
        value_sub_fields: LpSignatoryFields(
          asa_commitment_amount: str("5000000"),
          individual_subscribername_signaturepage: str("Jane Smith"),
          entity_authorizedname_signaturepage: str("Entity Auth"),
        ),
      ),
    )
  let target = example_mappings.transform(src)
  target.sf_agreement_null_signer_first_name.value |> should.equal("Jane")
}

pub fn w9_tin_type_ein_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      w9: W9Type(
        ..ds().w9,
        value_sub_fields: W9Fields(
          w9_parti_ssn1: str(""),
          w9_parti_ein1: str(""),
          w9_line2: str(""),
        ),
      ),
    )
  let target = example_mappings.transform(src)
  target.sf_tax_form_w9_us_tin_type_c.selected_key |> should.equal("EIN")
}

pub fn w9_tin_type_ssn_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      w9: W9Type(
        ..ds().w9,
        value_sub_fields: W9Fields(
          w9_parti_ssn1: str("123-45-6789"),
          w9_parti_ein1: str(""),
          w9_line2: str(""),
        ),
      ),
    )
  let target = example_mappings.transform(src)
  target.sf_tax_form_w9_us_tin_type_c.selected_key |> should.equal("SSN")
}

pub fn w9_tin_type_line2_present_test() {
  let src =
    SourceTableFieldsMap(
      ..ds(),
      w9: W9Type(
        ..ds().w9,
        value_sub_fields: W9Fields(
          w9_parti_ssn1: str(""),
          w9_parti_ein1: str(""),
          w9_line2: str("Some LLC"),
        ),
      ),
    )
  let target = example_mappings.transform(src)
  target.sf_tax_form_w9_us_tin_type_c.selected_key |> should.equal("")
}
