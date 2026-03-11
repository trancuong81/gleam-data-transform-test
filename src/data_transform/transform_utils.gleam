//// Collection and merge utilities.
//// Port of OCaml transform_utils.ml.

import data_transform/json_value.{type JsonValue, JsonObject}
import gleam/dict
import gleam/list

/// Identity function.
pub fn identity(x: a) -> a {
  x
}

/// Group items by a key function, preserving insertion order.
pub fn group_by(
  items: List(a),
  key_fn: fn(a) -> String,
  value_fn: fn(a) -> b,
) -> List(#(String, List(b))) {
  let result =
    list.fold(items, #(dict.new(), []), fn(acc, item) {
      let #(groups, order) = acc
      let k = key_fn(item)
      let v = value_fn(item)
      case dict.get(groups, k) {
        Ok(existing) -> #(
          dict.insert(groups, k, list.append(existing, [v])),
          order,
        )
        Error(_) -> #(dict.insert(groups, k, [v]), [k, ..order])
      }
    })
  let #(groups, order) = result
  order
  |> list.reverse
  |> list.filter_map(fn(k) {
    case dict.get(groups, k) {
      Ok(vs) -> Ok(#(k, vs))
      Error(_) -> Error(Nil)
    }
  })
}

/// Keep last value per key, preserving first-seen order.
pub fn merge_by(
  items: List(a),
  key_fn: fn(a) -> String,
  value_fn: fn(a) -> b,
) -> List(#(String, b)) {
  let result =
    list.fold(items, #(dict.new(), []), fn(acc, item) {
      let #(merged, order) = acc
      let k = key_fn(item)
      let new_order = case dict.has_key(merged, k) {
        True -> order
        False -> [k, ..order]
      }
      #(dict.insert(merged, k, value_fn(item)), new_order)
    })
  let #(merged, order) = result
  order
  |> list.reverse
  |> list.filter_map(fn(k) {
    case dict.get(merged, k) {
      Ok(v) -> Ok(#(k, v))
      Error(_) -> Error(Nil)
    }
  })
}

/// Map over key-value pairs.
pub fn map_values(
  pairs: List(#(String, a)),
  f: fn(String, a) -> b,
) -> List(#(String, b)) {
  list.map(pairs, fn(pair) { #(pair.0, f(pair.0, pair.1)) })
}

/// Deep merge a list of JSON objects. Later values override earlier ones.
/// Nested objects are merged recursively.
pub fn deep_merge(objects: List(JsonValue)) -> JsonValue {
  list.fold(objects, JsonObject(dict.new()), deep_merge_two)
}

fn deep_merge_two(acc: JsonValue, obj: JsonValue) -> JsonValue {
  case acc, obj {
    JsonObject(acc_fields), JsonObject(obj_fields) -> {
      let merged =
        dict.to_list(obj_fields)
        |> list.fold(acc_fields, fn(fields, pair) {
          let #(key, value) = pair
          case dict.get(fields, key), value {
            Ok(JsonObject(_) as existing), JsonObject(_) ->
              dict.insert(fields, key, deep_merge_two(existing, value))
            _, _ -> dict.insert(fields, key, value)
          }
        })
      JsonObject(merged)
    }
    _, other -> other
  }
}
