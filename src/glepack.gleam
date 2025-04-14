//// This Module provides functions to encode and decode MessagePack data

import gleam/bit_array
import msgpack/error

import msgpack/data
import msgpack/decode as msgpack_decode
import msgpack/encode

/// Convert a Gleam value to MessagePack format.
/// 
/// This function takes any value that can be represented by `data.Value` and 
/// converts it to MessagePack binary format.
/// 
/// ## Examples
/// 
/// ```gleam
/// pack(data.Integer(42))
/// // -> Ok(<<42>>)
/// 
/// let map = dict.new() |> dict.insert(data.String("key"), data.String("value"))
/// pack(data.Map(map))
/// // -> Ok binary data representing the map
/// ```
pub fn pack(value: data.Value) -> Result(BitArray, Nil) {
  encode.value(value)
}

/// Convert a Gleam value to MessagePack format, raising an error if conversion fails.
/// 
/// This is similar to `pack` but returns the binary data directly instead of a Result.
/// If encoding fails, this function will panic.
/// 
/// ## Examples
/// 
/// ```gleam
/// pack_strict(data.Integer(42))
/// // -> <<42>>
/// ```
pub fn pack_strict(value: data.Value) -> BitArray {
  case pack(value) {
    Ok(binary) -> binary
    Error(_) -> panic as "Failed to encode value to MessagePack format"
  }
}

/// Decode a MessagePack binary into a Gleam value.
/// 
/// This function takes MessagePack formatted binary data and converts it
/// to a `data.Value` type. It also returns the unconsumed portion of the input
/// if there are remaining bytes after decoding.
/// 
/// ## Examples
/// 
/// ```gleam
/// unpack(<<163, 102, 111, 111>>)
/// // -> Ok(#(data.String("foo"), <<>>))
/// ```
pub fn unpack(
  input: BitArray,
) -> Result(#(data.Value, BitArray), error.DecodeError) {
  msgpack_decode.value(input)
}

/// Decode a MessagePack binary into a Gleam value, raising an error if decoding fails.
/// 
/// This is similar to `unpack` but returns the value directly instead of a Result.
/// If decoding fails, this function will panic.
/// 
/// ## Examples
/// 
/// ```gleam
/// unpack_strict(<<163, 102, 111, 111>>)
/// // -> #(data.String("foo"), <<>>)
/// ```
pub fn unpack_strict(input: BitArray) -> #(data.Value, BitArray) {
  case unpack(input) {
    Ok(result) -> result
    Error(_) -> panic as "Failed to decode MessagePack data"
  }
}

/// Decode a complete MessagePack binary into a Gleam value.
/// 
/// Unlike `unpack`, this function expects the input to contain exactly one
/// MessagePack value with no trailing data. If there are remaining bytes after
/// decoding, an error is returned.
/// 
/// ## Examples
/// 
/// ```gleam
/// unpack_exact(<<163, 102, 111, 111>>)
/// // -> Ok(data.String("foo"))
/// 
/// unpack_exact(<<163, 102, 111, 111, 192>>)
/// // -> Error(Nil) because there is a remaining byte
/// ```
pub fn unpack_exact(input: BitArray) -> Result(data.Value, error.DecodeError) {
  case unpack(input) {
    Ok(#(value, rest)) ->
      case bit_array.byte_size(rest) {
        0 -> Ok(value)
        _ -> Error(error.IncompleteData)
      }
    Error(e) -> Error(e)
  }
}

/// Decode a complete MessagePack binary, raising an error if decoding fails or if 
/// there is trailing data.
/// 
/// This is similar to `unpack_exact` but returns the value directly instead of a Result.
/// If decoding fails or there is trailing data, this function will panic.
/// 
/// ## Examples
/// 
/// ```gleam
/// unpack_exact_strict(<<163, 102, 111, 111>>)
/// // -> data.String("foo")
/// ```
pub fn unpack_exact_strict(input: BitArray) -> data.Value {
  case unpack_exact(input) {
    Ok(value) -> value
    Error(_) ->
      panic as "Failed to decode MessagePack data or found trailing bytes"
  }
}
