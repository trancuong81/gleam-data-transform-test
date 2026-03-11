//// CLI entry point for data transformation.
//// Port of OCaml bin/main.ml.

import data_transform/example_mappings.{str}
import data_transform/json_value.{type JsonValue, JsonFloat, JsonObject, JsonString}
import data_transform/proto/data_types.{MultipleCheckboxType}
import data_transform/proto/source_table.{
  type SourceTableFieldsMap, LpSignatoryFields, LpSignatoryType,
  SourceTableFieldsMap, W9Fields, W9Type,
}
import data_transform/proto/target_table.{type TargetTableFieldsMap}
import gleam/dict
import gleam/io
import gleam/list

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

/// Convert JSON input to SourceTableFieldsMap.
pub fn json_to_source(json: JsonValue) -> SourceTableFieldsMap {
  let fields = json_value.as_object(json)

  let lp_sub = case dict.get(fields, "lpSignatory") {
    Ok(lp_json) -> {
      let lp_fields = json_value.as_object(lp_json)
      case dict.get(lp_fields, "valueSubFields") {
        Ok(sf) -> json_value.as_object(sf)
        Error(_) -> dict.new()
      }
    }
    Error(_) -> dict.new()
  }

  let w9_sub = case dict.get(fields, "w9") {
    Ok(w9_json) -> {
      let w9_fields = json_value.as_object(w9_json)
      case dict.get(w9_fields, "valueSubFields") {
        Ok(sf) -> json_value.as_object(sf)
        Error(_) -> dict.new()
      }
    }
    Error(_) -> dict.new()
  }

  SourceTableFieldsMap(
    lp_signatory: LpSignatoryType(
      type_id: "CustomCompound",
      value_sub_fields: LpSignatoryFields(
        asa_commitment_amount: str(
          get_sub_value(lp_sub, "asaCommitmentAmount"),
        ),
        individual_subscribername_signaturepage: str(
          get_sub_value(lp_sub, "individualSubscribernameSignaturepage"),
        ),
        entity_authorizedname_signaturepage: str(
          get_sub_value(lp_sub, "entityAuthorizednameSignaturepage"),
        ),
      ),
      sub_field_keys_in_order: [],
      label: "",
    ),
    asa_fullname_investorname_amlquestionnaire: str(
      get_field_value(fields, "asaFullnameInvestornameAmlquestionnaire"),
    ),
    asa_fullname_investorname_generalinfo1: str(
      get_field_value(fields, "asaFullnameInvestornameGeneralinfo1"),
    ),
    luxsentity_regulatedstatus_part2_duediligencequestionnaire: MultipleCheckboxType(
      type_id: "MultipleCheckbox",
      selected_keys: get_field_selected_keys(
        fields,
        "luxsentityRegulatedstatusPart2Duediligencequestionnaire",
      ),
      all_option_keys_in_order: [],
      all_option_labels_in_order: [],
    ),
    indi_internationalsupplements_part1_duediligencequestionnaire: MultipleCheckboxType(
      type_id: "MultipleCheckbox",
      selected_keys: get_field_selected_keys(
        fields,
        "indiInternationalsupplementsPart1Duediligencequestionnaire",
      ),
      all_option_keys_in_order: [],
      all_option_labels_in_order: [],
    ),
    entity_internationalsupplements_part1_duediligencequestionnaire: MultipleCheckboxType(
      type_id: "MultipleCheckbox",
      selected_keys: get_field_selected_keys(
        fields,
        "entityInternationalsupplementsPart1Duediligencequestionnaire",
      ),
      all_option_keys_in_order: [],
      all_option_labels_in_order: [],
    ),
    w9: W9Type(
      type_id: "CustomCompound",
      value_sub_fields: W9Fields(
        w9_parti_ssn1: str(get_sub_value(w9_sub, "w9PartiSsn1")),
        w9_parti_ein1: str(get_sub_value(w9_sub, "w9PartiEin1")),
        w9_line2: str(get_sub_value(w9_sub, "w9Line2")),
      ),
      sub_field_keys_in_order: [],
      label: "",
    ),
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

/// Convert TargetTableFieldsMap to JSON output format (matching OCaml's output).
pub fn target_to_json(target: TargetTableFieldsMap) -> JsonValue {
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
                        #(
                          "value",
                          JsonFloat(
                            target.sf_agreement_null_commitment_c.value_sub_fields.amount.value,
                          ),
                        ),
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
            #(
              "value",
              JsonString(target.sf_account_subscription_investor_name.value),
            ),
          ]),
        ),
      ),
      #(
        "sfAccountSubscriptionInvestorWlcPubliclyListedOnAStockExchangeC",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("RadioGroup")),
            #(
              "selectedKey",
              JsonString(
                target
                  .sf_account_subscription_investor_wlc_publicly_listed_on_a_stock_exchange_c
                  .selected_key,
              ),
            ),
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
                list.map(
                  target
                    .sf_agreement_null_wlc_international_supplements_c
                    .selected_keys,
                  JsonString,
                ),
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
            #(
              "value",
              JsonString(target.sf_agreement_null_signer_first_name.value),
            ),
          ]),
        ),
      ),
      #(
        "sfAgreementNullSignerMiddleName",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("String")),
            #(
              "value",
              JsonString(target.sf_agreement_null_signer_middle_name.value),
            ),
          ]),
        ),
      ),
      #(
        "sfAgreementNullSignerLastName",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("String")),
            #(
              "value",
              JsonString(target.sf_agreement_null_signer_last_name.value),
            ),
          ]),
        ),
      ),
      #(
        "sfTaxFormW9UsTinTypeC",
        JsonObject(
          dict.from_list([
            #("typeId", JsonString("RadioGroup")),
            #(
              "selectedKey",
              JsonString(target.sf_tax_form_w9_us_tin_type_c.selected_key),
            ),
          ]),
        ),
      ),
    ]),
  )
}
