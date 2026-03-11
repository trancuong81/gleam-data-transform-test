//// CLI entry point for data transformation.
//// Port of OCaml bin/main.ml.

import data_transform/example_mappings.{
  type TargetFields, LpSignatoryFields, SourceFields, W9Fields,
}
import data_transform/json_value.{type JsonValue, JsonFloat, JsonObject, JsonString}
import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{None, Some}

@external(javascript, "./main_ffi.mjs", "read_file")
fn read_file(path: String) -> Result(String, String)

@external(javascript, "./main_ffi.mjs", "get_args")
fn get_args() -> List(String)

@external(javascript, "./main_ffi.mjs", "write_stdout")
fn write_stdout(s: String) -> Nil

pub fn main() {
  let args = get_args()
  case args {
    [input_path, ..] -> {
      case read_file(input_path) {
        Ok(content) -> {
          case json_value.parse(content) {
            Ok(json) -> {
              let source = json_to_source(json)
              let target = example_mappings.transform(source)
              let result = target_to_json(target)
              write_stdout(json_value.to_string(result) <> "\n")
            }
            Error(_) -> io.println("Error: failed to parse JSON")
          }
        }
        Error(msg) -> io.println("Error reading file: " <> msg)
      }
    }
    _ -> io.println("Usage: gleam run -m data_transform/main -- <values.json>")
  }
}

/// Convert JSON input to SourceFields.
pub fn json_to_source(json: JsonValue) -> example_mappings.SourceFields {
  let fields = json_value.as_object(json)

  let lp_signatory = case dict.get(fields, "lpSignatory") {
    Ok(lp_json) -> {
      let lp_fields = json_value.as_object(lp_json)
      let sub_fields = case dict.get(lp_fields, "valueSubFields") {
        Ok(sf) -> json_value.as_object(sf)
        Error(_) -> dict.new()
      }
      Some(LpSignatoryFields(
        commitment_amount: get_sub_value(sub_fields, "asaCommitmentAmount"),
        individual_name: get_sub_value(
          sub_fields,
          "individualSubscribernameSignaturepage",
        ),
        entity_name: get_sub_value(
          sub_fields,
          "entityAuthorizednameSignaturepage",
        ),
      ))
    }
    Error(_) -> None
  }

  let w9 = case dict.get(fields, "w9") {
    Ok(w9_json) -> {
      let w9_fields = json_value.as_object(w9_json)
      let sub_fields = case dict.get(w9_fields, "valueSubFields") {
        Ok(sf) -> json_value.as_object(sf)
        Error(_) -> dict.new()
      }
      Some(W9Fields(
        ssn: get_sub_value(sub_fields, "w9PartiSsn1"),
        ein: get_sub_value(sub_fields, "w9PartiEin1"),
        line2: get_sub_value(sub_fields, "w9Line2"),
      ))
    }
    Error(_) -> None
  }

  SourceFields(
    lp_signatory: lp_signatory,
    aml_name: get_field_value(
      fields,
      "asaFullnameInvestornameAmlquestionnaire",
    ),
    general_name: get_field_value(
      fields,
      "asaFullnameInvestornameGeneralinfo1",
    ),
    regulated_keys: get_field_selected_keys(
      fields,
      "luxsentityRegulatedstatusPart2Duediligencequestionnaire",
    ),
    indi_intl_keys: get_field_selected_keys(
      fields,
      "indiInternationalsupplementsPart1Duediligencequestionnaire",
    ),
    entity_intl_keys: get_field_selected_keys(
      fields,
      "entityInternationalsupplementsPart1Duediligencequestionnaire",
    ),
    w9: w9,
  )
}

fn get_sub_value(
  fields: dict.Dict(String, JsonValue),
  key: String,
) -> String {
  case dict.get(fields, key) {
    Ok(field_json) -> {
      let obj = json_value.as_object(field_json)
      case dict.get(obj, "value") {
        Ok(JsonString(s)) -> s
        _ -> ""
      }
    }
    Error(_) -> ""
  }
}

fn get_field_value(
  fields: dict.Dict(String, JsonValue),
  key: String,
) -> String {
  case dict.get(fields, key) {
    Ok(field_json) -> {
      let obj = json_value.as_object(field_json)
      case dict.get(obj, "value") {
        Ok(JsonString(s)) -> s
        _ -> ""
      }
    }
    Error(_) -> ""
  }
}

fn get_field_selected_keys(
  fields: dict.Dict(String, JsonValue),
  key: String,
) -> List(String) {
  case dict.get(fields, key) {
    Ok(field_json) -> {
      let obj = json_value.as_object(field_json)
      case dict.get(obj, "selectedKeys") {
        Ok(json_value.JsonArray(items)) ->
          list.filter_map(items, fn(item) {
            case item {
              JsonString(s) -> Ok(s)
              _ -> Error(Nil)
            }
          })
        _ -> []
      }
    }
    Error(_) -> []
  }
}

/// Convert TargetFields to JSON output format (matching OCaml's output).
pub fn target_to_json(target: TargetFields) -> JsonValue {
  JsonObject(
    dict.from_list([
      #(
        "sfAgreementNullCommitmentC",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("Money")),
            #(
              "valueSubFields",
              JsonObject(
                dict.from_list([
                  #(
                    "amount",
                    JsonObject(
                      dict.from_list([
                        #("typeId", JsonString("Number")),
                        #("value", JsonFloat(target.commitment_amount)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
      #(
        "sfAccountSubscriptionInvestorName",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("String")),
            #("value", JsonString(target.investor_name)),
          ]),
        ),
      ),
      #(
        "sfAccountSubscriptionInvestorWlcPubliclyListedOnAStockExchangeC",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("RadioGroup")),
            #("selectedKey", JsonString(target.regulated_status)),
          ]),
        ),
      ),
      #(
        "sfAgreementNullWlcInternationalSupplementsC",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("MultipleCheckbox")),
            #(
              "selectedKeys",
              json_value.JsonArray(
                list.map(target.intl_supplements, JsonString),
              ),
            ),
          ]),
        ),
      ),
      #(
        "sfAgreementNullSignerFirstName",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("String")),
            #("value", JsonString(target.signer_first_name)),
          ]),
        ),
      ),
      #(
        "sfAgreementNullSignerMiddleName",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("String")),
            #("value", JsonString(target.signer_middle_name)),
          ]),
        ),
      ),
      #(
        "sfAgreementNullSignerLastName",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("String")),
            #("value", JsonString(target.signer_last_name)),
          ]),
        ),
      ),
      #(
        "sfTaxFormW9UsTinTypeC",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("RadioGroup")),
            #("selectedKey", JsonString(target.tin_type)),
          ]),
        ),
      ),
    ]),
  )
}
