//// JSON value representation for the transformation pipeline.
//// Equivalent to Yojson.Safe.t in the OCaml version.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string_tree

pub type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonInt(Int)
  JsonFloat(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(Dict(String, JsonValue))
}

/// Decode a dynamic value into JsonValue
pub fn decoder() -> decode.Decoder(JsonValue) {
  decode.one_of(decode.string |> decode.map(JsonString), [
    decode.int |> decode.map(JsonInt),
    decode.float |> decode.map(JsonFloat),
    decode.bool |> decode.map(JsonBool),
    decode.list(decode.dynamic)
      |> decode.map(fn(items) {
        let decoded =
          list.filter_map(items, fn(item) {
            case decode.run(item, decoder()) {
              Ok(v) -> Ok(v)
              Error(_) -> Error(Nil)
            }
          })
        JsonArray(decoded)
      }),
    decode.dict(decode.string, decode.dynamic)
      |> decode.map(fn(d) {
        let decoded =
          dict.to_list(d)
          |> list.filter_map(fn(pair) {
            case decode.run(pair.1, decoder()) {
              Ok(v) -> Ok(#(pair.0, v))
              Error(_) -> Error(Nil)
            }
          })
          |> dict.from_list
        JsonObject(decoded)
      }),
    decode.success(JsonNull),
  ])
}

/// Parse a JSON string into a JsonValue
pub fn parse(json_string: String) -> Result(JsonValue, json.DecodeError) {
  json.parse(json_string, decoder())
}

/// Encode a JsonValue to a JSON string
pub fn to_string(value: JsonValue) -> String {
  to_json(value)
  |> json.to_string_tree
  |> string_tree.to_string
}

/// Encode a JsonValue to gleam_json's Json type
pub fn to_json(value: JsonValue) -> json.Json {
  case value {
    JsonNull -> json.null()
    JsonBool(b) -> json.bool(b)
    JsonInt(n) -> json.int(n)
    JsonFloat(f) -> json.float(f)
    JsonString(s) -> json.string(s)
    JsonArray(items) -> json.array(items, to_json)
    JsonObject(fields) -> {
      dict.to_list(fields)
      |> list.map(fn(pair) { #(pair.0, to_json(pair.1)) })
      |> json.object
    }
  }
}

/// Get a string value, returning None for non-strings
pub fn as_string(value: JsonValue) -> Option(String) {
  case value {
    JsonString(s) -> Some(s)
    _ -> None
  }
}

/// Get fields from a JSON object, returning empty dict for non-objects
pub fn as_object(value: JsonValue) -> Dict(String, JsonValue) {
  case value {
    JsonObject(fields) -> fields
    _ -> dict.new()
  }
}

/// Get items from a JSON array, returning empty list for non-arrays
pub fn as_array(value: JsonValue) -> List(JsonValue) {
  case value {
    JsonArray(items) -> items
    _ -> []
  }
}
