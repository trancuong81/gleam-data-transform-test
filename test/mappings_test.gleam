import data_transform/json_path
import data_transform/json_value.{JsonObject, JsonString}
import data_transform/mappings
import gleam/dict
import gleam/option.{Some}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn textbox_mapping_test() {
  let input =
    JsonObject(
      dict.from_list([
        #(
          "subdoc",
          JsonObject(
            dict.from_list([
              #(
                "lp_signatory",
                JsonObject(
                  dict.from_list([
                    #(
                      "asa_commitment_amount",
                      JsonObject(
                        dict.from_list([#("value", JsonString("1000000"))]),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

  let mapping =
    mappings.textbox_mapping(
      name: "sf_Agreement_null_Commitment_c",
      input_paths: [
        #("subdoc", ["subdoc", "lp_signatory", "asa_commitment_amount"]),
      ],
      output_path: ["sf_Agreement_null_Commitment_c"],
    )

  let result = mappings.apply_mapping(mapping, input)
  json_path.get_string(result, ["sf_Agreement_null_Commitment_c", "value"])
  |> should.equal(Some("1000000"))
}

pub fn checkbox_mapping_test() {
  let input =
    JsonObject(
      dict.from_list([
        #(
          "subdoc",
          JsonObject(
            dict.from_list([
              #(
                "luxsentity_regulatedstatus_part2_duediligencequestionnaire",
                JsonObject(
                  dict.from_list([
                    #(
                      "selectedKeys",
                      json_value.JsonArray([
                        JsonString(
                          "yes_luxsentity_regulatedstatus_part2_duediligencequestionnaire",
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

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

  let mapping =
    mappings.checkbox_mapping(
      name: "sf_Account_SubscriptionInvestor_WLC_Publicly_Listed_On_A_Stock_Exchange_c",
      input_paths: [
        #("subdoc", [
          "subdoc",
          "luxsentity_regulatedstatus_part2_duediligencequestionnaire",
        ]),
      ],
      output_path: [
        "sf_Account_SubscriptionInvestor_WLC_Publicly_Listed_On_A_Stock_Exchange_c",
      ],
      option_map: option_map,
    )

  let result = mappings.apply_mapping(mapping, input)
  json_path.get_string_list(result, [
    "sf_Account_SubscriptionInvestor_WLC_Publicly_Listed_On_A_Stock_Exchange_c",
    "selectedKeys",
  ])
  |> should.equal(["true"])
}
