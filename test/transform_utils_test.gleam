import data_transform/json_value.{JsonInt, JsonObject}
import data_transform/transform_utils
import gleam/dict
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn identity_test() {
  transform_utils.identity(42)
  |> should.equal(42)
  transform_utils.identity("hello")
  |> should.equal("hello")
}

pub fn group_by_test() {
  let items = [#("a", 1), #("b", 2), #("a", 3)]
  let result =
    transform_utils.group_by(items, fn(pair) { pair.0 }, fn(pair) { pair.1 })
  let a_values = case dict.get(dict.from_list(result), "a") {
    Ok(v) -> v
    Error(_) -> []
  }
  a_values |> should.equal([1, 3])
  let b_values = case dict.get(dict.from_list(result), "b") {
    Ok(v) -> v
    Error(_) -> []
  }
  b_values |> should.equal([2])
}

pub fn merge_by_test() {
  let items = [#("a", 1), #("b", 2), #("c", 3)]
  let result =
    transform_utils.merge_by(items, fn(pair) { pair.0 }, fn(pair) { pair.1 })
  let result_dict = dict.from_list(result)
  dict.get(result_dict, "a") |> should.equal(Ok(1))
  dict.get(result_dict, "c") |> should.equal(Ok(3))
}

pub fn map_values_test() {
  let pairs = [#("x", 1), #("y", 2)]
  let result = transform_utils.map_values(pairs, fn(_k, v) { v * 10 })
  let result_dict = dict.from_list(result)
  dict.get(result_dict, "x") |> should.equal(Ok(10))
  dict.get(result_dict, "y") |> should.equal(Ok(20))
}

pub fn deep_merge_test() {
  let a =
    JsonObject(
      dict.from_list([
        #("x", JsonInt(1)),
        #("nested", JsonObject(dict.from_list([#("a", JsonInt(1))]))),
      ]),
    )
  let b =
    JsonObject(
      dict.from_list([
        #("y", JsonInt(2)),
        #("nested", JsonObject(dict.from_list([#("b", JsonInt(2))]))),
      ]),
    )
  let result = transform_utils.deep_merge([a, b])
  let expected =
    JsonObject(
      dict.from_list([
        #("x", JsonInt(1)),
        #("y", JsonInt(2)),
        #(
          "nested",
          JsonObject(dict.from_list([#("a", JsonInt(1)), #("b", JsonInt(2))])),
        ),
      ]),
    )
  result |> should.equal(expected)
}

pub fn deep_merge_overwrite_test() {
  let a = JsonObject(dict.from_list([#("x", JsonInt(1))]))
  let b = JsonObject(dict.from_list([#("x", JsonInt(2))]))
  let result = transform_utils.deep_merge([a, b])
  let expected = JsonObject(dict.from_list([#("x", JsonInt(2))]))
  result |> should.equal(expected)
}
