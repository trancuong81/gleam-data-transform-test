//// JSON path navigation utilities.
//// Port of OCaml json_path.ml — operates on JsonValue type.

import data_transform/json_value.{
  type JsonValue, JsonArray, JsonObject, JsonString,
}
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}

/// Navigate a JSON value by a list of keys.
pub fn get_path(json: JsonValue, path: List(String)) -> Option(JsonValue) {
  list.fold(path, Some(json), fn(acc, key) {
    case acc {
      Some(JsonObject(fields)) -> dict.get(fields, key) |> option.from_result
      _ -> None
    }
  })
}

/// Set a value at a nested path, creating intermediate objects as needed.
pub fn set_path(
  json: JsonValue,
  path: List(String),
  value: JsonValue,
) -> JsonValue {
  case path {
    [] -> value
    [key] -> {
      let fields = json_value.as_object(json)
      JsonObject(dict.insert(fields, key, value))
    }
    [key, ..rest] -> {
      let fields = json_value.as_object(json)
      let child = case dict.get(fields, key) {
        Ok(v) -> v
        Error(_) -> JsonObject(dict.new())
      }
      let updated_child = set_path(child, rest, value)
      JsonObject(dict.insert(fields, key, updated_child))
    }
  }
}

/// Get a string value at the given path.
pub fn get_string(json: JsonValue, path: List(String)) -> Option(String) {
  case get_path(json, path) {
    Some(JsonString(s)) -> Some(s)
    _ -> None
  }
}

/// Get a string value at the given path, defaulting to "".
pub fn get_string_or_empty(json: JsonValue, path: List(String)) -> String {
  case get_string(json, path) {
    Some(s) -> s
    None -> ""
  }
}

/// Get a list of strings at the given path.
pub fn get_string_list(json: JsonValue, path: List(String)) -> List(String) {
  case get_path(json, path) {
    Some(JsonArray(items)) ->
      list.filter_map(items, fn(item) {
        case item {
          JsonString(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    _ -> []
  }
}
