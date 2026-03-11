//// Concrete field transformations.
//// Port of OCaml example_mappings.ml.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// --- Types ---

pub type NameParts {
  NameParts(first_name: String, middle_name: String, last_name: String)
}

/// Source table fields (mirrors SourceTableFieldsMap from proto)
pub type SourceFields {
  SourceFields(
    lp_signatory: Option(LpSignatoryFields),
    aml_name: String,
    general_name: String,
    regulated_keys: List(String),
    indi_intl_keys: List(String),
    entity_intl_keys: List(String),
    w9: Option(W9Fields),
  )
}

pub type LpSignatoryFields {
  LpSignatoryFields(
    commitment_amount: String,
    individual_name: String,
    entity_name: String,
  )
}

pub type W9Fields {
  W9Fields(ssn: String, ein: String, line2: String)
}

/// Target table fields (mirrors TargetTableFieldsMap from proto)
pub type TargetFields {
  TargetFields(
    commitment_amount: Float,
    investor_name: String,
    regulated_status: String,
    intl_supplements: List(String),
    signer_first_name: String,
    signer_middle_name: String,
    signer_last_name: String,
    tin_type: String,
  )
}

// --- Helpers ---

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

// --- Mapping Functions ---

fn map_commitment(src: SourceFields) -> Float {
  let raw = case src.lp_signatory {
    Some(lp) -> lp.commitment_amount
    None -> ""
  }
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

fn map_investor_name(src: SourceFields) -> String {
  first_non_empty([src.aml_name, src.general_name])
}

fn map_regulated_status(src: SourceFields) -> String {
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
    list.filter_map(src.regulated_keys, fn(k) {
      case lookup(k, option_map) {
        Some(v) -> Ok(v)
        None -> Error(Nil)
      }
    })
  case mapped {
    [first, ..] -> first
    [] -> ""
  }
}

fn map_international_supplements(src: SourceFields) -> List(String) {
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
  let all_keys = list.append(src.indi_intl_keys, src.entity_intl_keys)
  let mapped =
    list.filter_map(all_keys, fn(k) {
      case lookup(k, option_map) {
        Some(v) -> Ok(v)
        None -> Error(Nil)
      }
    })
  deduplicate(mapped)
}

fn map_signer_name(src: SourceFields) -> NameParts {
  let fullname = case src.lp_signatory {
    Some(lp) -> first_non_empty([lp.individual_name, lp.entity_name])
    None -> ""
  }
  split_name(fullname)
}

fn map_w9_tin_type(src: SourceFields) -> String {
  case src.w9 {
    Some(w9) ->
      case w9.line2 != "" {
        True -> ""
        False ->
          case w9.ssn != "" {
            True -> "SSN"
            False -> "EIN"
          }
      }
    None -> "EIN"
  }
}

// --- Main Transform ---

/// Apply all 6 mappings to source fields, producing target fields.
pub fn transform(src: SourceFields) -> TargetFields {
  let commitment = map_commitment(src)
  let investor_name = map_investor_name(src)
  let regulated_status = map_regulated_status(src)
  let intl_supplements = map_international_supplements(src)
  let signer = map_signer_name(src)
  let tin_type = map_w9_tin_type(src)
  TargetFields(
    commitment_amount: commitment,
    investor_name: investor_name,
    regulated_status: regulated_status,
    intl_supplements: intl_supplements,
    signer_first_name: signer.first_name,
    signer_middle_name: signer.middle_name,
    signer_last_name: signer.last_name,
    tin_type: tin_type,
  )
}

// --- Test Helper ---

/// Default source for testing.
pub fn default_source() -> SourceFields {
  SourceFields(
    lp_signatory: Some(LpSignatoryFields(
      commitment_amount: "5000000",
      individual_name: "",
      entity_name: "John Doe",
    )),
    aml_name: "",
    general_name: "ACME Corp",
    regulated_keys: [
      "yes_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
    ],
    indi_intl_keys: [],
    entity_intl_keys: [],
    w9: Some(W9Fields(ssn: "", ein: "", line2: "")),
  )
}
