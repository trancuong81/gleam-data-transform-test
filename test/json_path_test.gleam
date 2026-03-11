import data_transform/json_path
import data_transform/json_value.{JsonInt, JsonObject, JsonString}
import gleam/dict
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn get_path_nested_test() {
  let json =
    JsonObject(
      dict.from_list([
        #(
          "a",
          JsonObject(
            dict.from_list([
              #("b", JsonObject(dict.from_list([#("c", JsonInt(42))]))),
            ]),
          ),
        ),
      ]),
    )
  json_path.get_path(json, ["a", "b", "c"])
  |> should.equal(Some(JsonInt(42)))
}

pub fn get_path_missing_test() {
  let json =
    JsonObject(
      dict.from_list([
        #("a", JsonObject(dict.from_list([#("b", JsonInt(1))]))),
      ]),
    )
  json_path.get_path(json, ["a", "x"])
  |> should.equal(None)
}

pub fn get_path_empty_test() {
  let json = JsonObject(dict.from_list([#("a", JsonInt(1))]))
  json_path.get_path(json, [])
  |> should.equal(Some(json))
}

pub fn set_path_nested_test() {
  let json = JsonObject(dict.new())
  let result = json_path.set_path(json, ["a", "b"], JsonString("hello"))
  let expected =
    JsonObject(
      dict.from_list([
        #("a", JsonObject(dict.from_list([#("b", JsonString("hello"))]))),
      ]),
    )
  result
  |> should.equal(expected)
}
