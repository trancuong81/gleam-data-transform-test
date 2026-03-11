//// Mapping engine for field transformations.
//// Port of OCaml mappings.ml.

import data_transform/json_path
import data_transform/json_value.{
  type JsonValue, JsonArray, JsonNull, JsonObject, JsonString,
}
import data_transform/transform_utils
import gleam/dict
import gleam/list
import gleam/option.{None, Some}

/// Input path specification: list of (alias, path) pairs.
pub type InputInfo =
  List(#(String, List(String)))

/// A mapping from source fields to a target field.
pub opaque type Mapping {
  Mapping(
    name: String,
    input_paths: InputInfo,
    output_path: List(String),
    transform: fn(JsonValue) -> JsonValue,
  )
}

pub fn mapping_name(m: Mapping) -> String {
  m.name
}

pub fn mapping_output_path(m: Mapping) -> List(String) {
  m.output_path
}

/// Get a value at a path, returning JsonNull if not found.
fn get_value(json: JsonValue, path: List(String)) -> JsonValue {
  case json_path.get_path(json, path) {
    Some(v) -> v
    None -> JsonNull
  }
}

/// Wrap a value in nested JSON objects according to path.
fn build_output(value: JsonValue, path: List(String)) -> JsonValue {
  list.fold_right(path, value, fn(acc, key) {
    case key {
      "" -> acc
      _ -> JsonObject(dict.from_list([#(key, acc)]))
    }
  })
}

/// Gather inputs from source JSON using input path specs.
fn gather_inputs(json: JsonValue, input_paths: InputInfo) -> JsonValue {
  let pairs =
    list.map(input_paths, fn(spec) { #(spec.0, get_value(json, spec.1)) })
  JsonObject(dict.from_list(pairs))
}

/// Create a textbox mapping: extracts first non-empty string from input paths.
pub fn textbox_mapping(
  name name: String,
  input_paths input_paths: InputInfo,
  output_path output_path: List(String),
) -> Mapping {
  let transform = fn(input_json: JsonValue) {
    let values = case input_json {
      JsonObject(fields) ->
        dict.values(fields)
        |> list.filter_map(fn(v) {
          case json_path.get_path(v, ["value"]) {
            Some(JsonString(s)) if s != "" -> Ok(s)
            _ -> Error(Nil)
          }
        })
      _ -> []
    }
    let joined = case values {
      [] -> ""
      [first, ..] -> first
    }
    build_output(
      JsonObject(dict.from_list([#("value", JsonString(joined))])),
      output_path,
    )
  }
  Mapping(name:, input_paths:, output_path:, transform:)
}

/// Create a checkbox mapping: maps selected keys through an option map.
pub fn checkbox_mapping(
  name name: String,
  input_paths input_paths: InputInfo,
  output_path output_path: List(String),
  option_map option_map: List(#(String, String)),
) -> Mapping {
  let transform = fn(input_json: JsonValue) {
    let selected_keys = case input_json {
      JsonObject(fields) ->
        dict.values(fields)
        |> list.flat_map(fn(v) {
          case v {
            JsonObject(_) ->
              case json_path.get_path(v, ["selectedKeys"]) {
                Some(JsonArray(keys)) ->
                  list.filter_map(keys, fn(k) {
                    case k {
                      JsonString(key) -> lookup(key, option_map)
                      _ -> Error(Nil)
                    }
                  })
                _ -> []
              }
            _ -> []
          }
        })
      _ -> []
    }
    // Deduplicate preserving order
    let unique = deduplicate(selected_keys)
    build_output(
      JsonObject(
        dict.from_list([
          #("selectedKeys", JsonArray(list.map(unique, JsonString))),
        ]),
      ),
      output_path,
    )
  }
  Mapping(name:, input_paths:, output_path:, transform:)
}

/// Create a custom mapping with an arbitrary transform function.
pub fn custom_mapping(
  name name: String,
  input_paths input_paths: InputInfo,
  output_path output_path: List(String),
  transform_fn transform_fn: fn(JsonValue) -> JsonValue,
) -> Mapping {
  let transform = fn(input_json: JsonValue) {
    let result = transform_fn(input_json)
    build_output(result, output_path)
  }
  Mapping(name:, input_paths:, output_path:, transform:)
}

/// Apply a single mapping to source JSON.
pub fn apply_mapping(mapping: Mapping, source: JsonValue) -> JsonValue {
  let input = gather_inputs(source, mapping.input_paths)
  mapping.transform(input)
}

/// Apply all mappings and deep-merge the results.
pub fn transform_all(mappings: List(Mapping), source: JsonValue) -> JsonValue {
  let results = list.map(mappings, fn(m) { apply_mapping(m, source) })
  transform_utils.deep_merge(results)
}

// --- Helpers ---

fn lookup(key: String, pairs: List(#(String, String))) -> Result(String, Nil) {
  case pairs {
    [] -> Error(Nil)
    [#(k, v), ..] if k == key -> Ok(v)
    [_, ..rest] -> lookup(key, rest)
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
