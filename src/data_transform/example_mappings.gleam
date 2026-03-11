//// Concrete field transformations.
//// Port of OCaml example_mappings.ml.
//// Uses proto-generated types directly from source_table.gleam and target_table.gleam.

import data_transform/proto/data_types.{
  type MultipleCheckboxType, type NumberType, type RadioGroupType,
  type StringType, MoneySubFields, MoneyType, MultipleCheckboxType, NumberType,
  RadioGroupType, StringType,
}
import data_transform/proto/source_table.{
  type SourceTableFieldsMap, LpSignatoryFields, LpSignatoryType,
  SourceTableFieldsMap, W9Fields, W9Type,
}
import data_transform/proto/target_table.{
  type TargetTableFieldsMap, TargetTableFieldsMap,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// --- Helpers ---

pub type NameParts {
  NameParts(first_name: String, middle_name: String, last_name: String)
}

pub fn split_name(fullname: String) -> NameParts {
  let trimmed = string.trim(fullname)
  case trimmed {
    "" -> NameParts(first_name: "", middle_name: "", last_name: "")
    _ -> {
      let parts =
        string.split(trimmed, " ")
        |> list.filter(fn(s) { s != "" })
      case parts {
        [] -> NameParts(first_name: "", middle_name: "", last_name: "")
        [single] ->
          NameParts(first_name: single, middle_name: "", last_name: single)
        [first, last] ->
          NameParts(first_name: first, middle_name: "", last_name: last)
        [first, ..rest] -> {
          let len = list.length(rest)
          let last = case list.last(rest) {
            Ok(l) -> l
            Error(_) -> ""
          }
          let middle =
            rest
            |> list.take(len - 1)
            |> string.join(" ")
          NameParts(first_name: first, middle_name: middle, last_name: last)
        }
      }
    }
  }
}

fn first_non_empty(values: List(String)) -> String {
  case list.find(values, fn(s) { s != "" }) {
    Ok(s) -> s
    Error(_) -> ""
  }
}

fn lookup(key: String, pairs: List(#(String, String))) -> Option(String) {
  case list.find(pairs, fn(pair) { pair.0 == key }) {
    Ok(pair) -> Some(pair.1)
    Error(_) -> None
  }
}

fn deduplicate(items: List(String)) -> List(String) {
  list.fold(items, [], fn(acc, item) {
    case list.contains(acc, item) {
      True -> acc
      False -> list.append(acc, [item])
    }
  })
}

/// Helper to create a StringType with just a value (convenience for tests/construction).
pub fn str(value: String) -> StringType {
  StringType(type_id: "String", value: value, regex: "", format_patterns: [])
}

/// Helper to create a default NumberType.
fn num(value: Float) -> NumberType {
  NumberType(
    type_id: "Number",
    value: value,
    decimal_places: 0,
    min_value: 0.0,
    max_value: 0.0,
  )
}

/// Helper to create a default MultipleCheckboxType.
fn checkbox(selected_keys: List(String)) -> MultipleCheckboxType {
  MultipleCheckboxType(
    type_id: "MultipleCheckbox",
    selected_keys: selected_keys,
    all_option_keys_in_order: [],
    all_option_labels_in_order: [],
  )
}

/// Helper to create a default RadioGroupType.
fn radio(selected_key: String) -> RadioGroupType {
  RadioGroupType(
    type_id: "RadioGroup",
    selected_key: selected_key,
    all_option_keys_in_order: [],
    all_option_labels_in_order: [],
  )
}

// --- Mapping Functions ---

fn map_commitment(src: SourceTableFieldsMap) -> Float {
  let raw = src.lp_signatory.value_sub_fields.asa_commitment_amount.value
  let amount_str = string.replace(raw, ",", "")
  case float.parse(amount_str) {
    Ok(f) -> f
    Error(_) -> {
      case int.parse(amount_str) {
        Ok(n) -> int.to_float(n)
        Error(_) -> 0.0
      }
    }
  }
}

fn map_investor_name(src: SourceTableFieldsMap) -> String {
  first_non_empty([
    src.asa_fullname_investorname_amlquestionnaire.value,
    src.asa_fullname_investorname_generalinfo1.value,
  ])
}

fn map_regulated_status(src: SourceTableFieldsMap) -> String {
  let option_map = [
    #(
      "yes_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
      "true",
    ),
    #(
      "no_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
      "false",
    ),
  ]
  let mapped =
    list.filter_map(
      src
        .luxsentity_regulatedstatus_part2_duediligencequestionnaire
        .selected_keys,
      fn(k) {
        case lookup(k, option_map) {
          Some(v) -> Ok(v)
          None -> Error(Nil)
        }
      },
    )
  case mapped {
    [first, ..] -> first
    [] -> ""
  }
}

fn map_international_supplements(src: SourceTableFieldsMap) -> List(String) {
  let option_map = [
    #(
      "eea_indi_internationalsupplements_part1_duediligencequestionnaire",
      "European Economic Area - Supplement",
    ),
    #(
      "uk_indi_internationalsupplements_part1_duediligencequestionnaire",
      "United Kingdom - Supplement",
    ),
    #(
      "swiss_indi_internationalsupplements_part1_duediligencequestionnaire",
      "Swiss - Supplement",
    ),
    #(
      "canada_indi_internationalsupplements_part1_duediligencequestionnaire",
      "Canadian - Supplement",
    ),
    #(
      "japan_indi_internationalsupplements_part1_duediligencequestionnaire",
      "Japanese - Supplement",
    ),
    #(
      "none_indi_internationalsupplements_part1_duediligencequestionnaire",
      "No Supplement",
    ),
    #(
      "eea_entity_internationalsupplements_part1_duediligencequestionnaire",
      "European Economic Area - Supplement",
    ),
    #(
      "uk_entity_internationalsupplements_part1_duediligencequestionnaire",
      "United Kingdom - Supplement",
    ),
    #(
      "swiss_entity_internationalsupplements_part1_duediligencequestionnaire",
      "Swiss - Supplement",
    ),
    #(
      "canada_entity_internationalsupplements_part1_duediligencequestionnaire",
      "Canadian - Supplement",
    ),
    #(
      "japan_entity_internationalsupplements_part1_duediligencequestionnaire",
      "Japanese - Supplement",
    ),
    #(
      "none_entity_internationalsupplements_part1_duediligencequestionnaire",
      "No Supplement",
    ),
  ]
  let all_keys =
    list.append(
      src
        .indi_internationalsupplements_part1_duediligencequestionnaire
        .selected_keys,
      src
        .entity_internationalsupplements_part1_duediligencequestionnaire
        .selected_keys,
    )
  let mapped =
    list.filter_map(all_keys, fn(k) {
      case lookup(k, option_map) {
        Some(v) -> Ok(v)
        None -> Error(Nil)
      }
    })
  deduplicate(mapped)
}

fn map_signer_name(src: SourceTableFieldsMap) -> NameParts {
  let lp = src.lp_signatory.value_sub_fields
  let fullname =
    first_non_empty([
      lp.individual_subscribername_signaturepage.value,
      lp.entity_authorizedname_signaturepage.value,
    ])
  split_name(fullname)
}

fn map_w9_tin_type(src: SourceTableFieldsMap) -> String {
  let w9 = src.w9.value_sub_fields
  case w9.w9_line2.value != "" {
    True -> ""
    False ->
      case w9.w9_parti_ssn1.value != "" {
        True -> "SSN"
        False -> "EIN"
      }
  }
}

// --- Main Transform ---

/// Apply all 6 mappings to source fields, producing target fields.
pub fn transform(src: SourceTableFieldsMap) -> TargetTableFieldsMap {
  let commitment = map_commitment(src)
  let investor_name = map_investor_name(src)
  let regulated_status = map_regulated_status(src)
  let intl_supplements = map_international_supplements(src)
  let signer = map_signer_name(src)
  let tin_type = map_w9_tin_type(src)
  TargetTableFieldsMap(
    sf_agreement_null_commitment_c: MoneyType(
      type_id: "Money",
      value_sub_fields: MoneySubFields(
        amount: num(commitment),
        iso_currency_code: str(""),
      ),
      sub_field_keys_in_order: ["amount"],
      label: "",
    ),
    sf_account_subscription_investor_name: str(investor_name),
    sf_account_subscription_investor_wlc_publicly_listed_on_a_stock_exchange_c: radio(
      regulated_status,
    ),
    sf_agreement_null_wlc_international_supplements_c: checkbox(
      intl_supplements,
    ),
    sf_agreement_null_signer_first_name: str(signer.first_name),
    sf_agreement_null_signer_middle_name: str(signer.middle_name),
    sf_agreement_null_signer_last_name: str(signer.last_name),
    sf_tax_form_w9_us_tin_type_c: radio(tin_type),
  )
}

// --- Test Helper ---

/// Default source for testing.
pub fn default_source() -> SourceTableFieldsMap {
  SourceTableFieldsMap(
    lp_signatory: LpSignatoryType(
      type_id: "CustomCompound",
      value_sub_fields: LpSignatoryFields(
        asa_commitment_amount: str("5000000"),
        individual_subscribername_signaturepage: str(""),
        entity_authorizedname_signaturepage: str("John Doe"),
      ),
      sub_field_keys_in_order: [],
      label: "",
    ),
    asa_fullname_investorname_amlquestionnaire: str(""),
    asa_fullname_investorname_generalinfo1: str("ACME Corp"),
    luxsentity_regulatedstatus_part2_duediligencequestionnaire: checkbox([
      "yes_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
    ]),
    indi_internationalsupplements_part1_duediligencequestionnaire: checkbox([]),
    entity_internationalsupplements_part1_duediligencequestionnaire: checkbox(
      [],
    ),
    w9: W9Type(
      type_id: "CustomCompound",
      value_sub_fields: W9Fields(
        w9_parti_ssn1: str(""),
        w9_parti_ein1: str(""),
        w9_line2: str(""),
      ),
      sub_field_keys_in_order: [],
      label: "",
    ),
  )
}
