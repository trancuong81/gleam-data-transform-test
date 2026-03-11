//// Schema loading from JSON constants files.
//// Port of OCaml schema.ml.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

/// Type constants loaded from data_types_constants.json
pub type TypeConstants {
  TypeConstants(
    type_id: String,
    regex: Option(String),
    format_patterns: List(String),
    options: List(String),
    min_value: Option(Float),
    max_value: Option(Float),
    sub_field_keys_in_order: List(String),
  )
}

pub type DataTypeConstants =
  Dict(String, TypeConstants)

fn type_constants_decoder() -> decode.Decoder(TypeConstants) {
  use type_id <- decode.field("typeId", decode.string)
  use regex <- decode.optional_field(
    "regex",
    None,
    decode.optional(decode.string),
  )
  use format_patterns <- decode.optional_field(
    "formatPatterns",
    [],
    decode.list(decode.string),
  )
  use options <- decode.optional_field(
    "options",
    [],
    decode.list(decode.string),
  )
  use min_value <- decode.optional_field(
    "min",
    None,
    decode.optional(decode.float),
  )
  use max_value <- decode.optional_field(
    "max",
    None,
    decode.optional(decode.float),
  )
  use sub_field_keys_in_order <- decode.optional_field(
    "subFieldKeysInOrder",
    [],
    decode.list(decode.string),
  )
  decode.success(TypeConstants(
    type_id:,
    regex:,
    format_patterns:,
    options:,
    min_value:,
    max_value:,
    sub_field_keys_in_order:,
  ))
}

/// Load data type constants from JSON file.
pub fn load_data_type_constants() -> Result(DataTypeConstants, String) {
  let path = "proto/data_types_constants.json"
  use content <- try_read(path)
  case
    json.parse(content, decode.dict(decode.string, type_constants_decoder()))
  {
    Ok(constants) -> Ok(constants)
    Error(e) -> Error("Failed to parse " <> path <> ": " <> string.inspect(e))
  }
}

pub fn find_type_constants(
  constants: DataTypeConstants,
  type_id: String,
) -> Option(TypeConstants) {
  case dict.get(constants, type_id) {
    Ok(tc) -> Some(tc)
    Error(_) -> None
  }
}

pub fn has_regex(tc: TypeConstants) -> Bool {
  option.is_some(tc.regex)
}

pub fn type_count(constants: DataTypeConstants) -> Int {
  dict.size(constants)
}

/// Convert snake_case to lowerCamelCase.
pub fn snake_to_camel(s: String) -> String {
  let graphemes = string.to_graphemes(s)
  do_snake_to_camel(graphemes, False, [])
  |> list.reverse
  |> string.join("")
}

fn do_snake_to_camel(
  chars: List(String),
  capitalize_next: Bool,
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> acc
    ["_", ..rest] -> do_snake_to_camel(rest, True, acc)
    [c, ..rest] if capitalize_next ->
      do_snake_to_camel(rest, False, [string.uppercase(c), ..acc])
    [c, ..rest] -> do_snake_to_camel(rest, False, [c, ..acc])
  }
}

fn try_read(
  path: String,
  next: fn(String) -> Result(a, String),
) -> Result(a, String) {
  case simplifile.read(path) {
    Ok(content) -> next(content)
    Error(_) -> Error("Failed to read file: " <> path)
  }
}
