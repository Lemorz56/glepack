//// This module provides functions to encode various data types into MessagePack format.

import gleam/bit_array
import gleam/dict
import gleam/list
import gleam/string
import glepack/data

// @external(javascript, "./float.mjs", "encodeFloat64")
@external(erlang, "float", "encode_float64")
fn encode_float64(value: Float) -> BitArray

/// Encode a nil value into MessagePack format
pub fn nil() -> Result(BitArray, Nil) {
  Ok(<<0xc0>>)
}

/// Encode a boolean value into MessagePack format
pub fn boolean(value: Bool) -> Result(BitArray, Nil) {
  case value {
    True -> Ok(<<0xc3>>)
    False -> Ok(<<0xc2>>)
  }
}

/// Encode an integer value into MessagePack format
/// The function returns a Result containing the encoded BitArray or an error.
pub fn integer(value: Int) -> Result(BitArray, Nil) {
  case value {
    n if n >= 0 && n <= 127 -> Ok(<<n:8>>)

    n if n >= -32 && n <= -1 -> {
      let unsigned = 256 + n
      Ok(<<unsigned:8>>)
    }

    n if n >= 0 && n <= 255 -> Ok(<<0xcc, n:8>>)

    n if n >= 0 && n <= 65_535 -> {
      let high_byte = n / 256
      let low_byte = n % 256
      Ok(<<0xcd, high_byte:8, low_byte:8>>)
    }

    n if n >= 0 && n <= 4_294_967_295 -> {
      let b1 = n / 16_777_216 % 256
      let b2 = n / 65_536 % 256
      let b3 = n / 256 % 256
      let b4 = n % 256
      Ok(<<0xce, b1:8, b2:8, b3:8, b4:8>>)
    }

    n if n >= -128 && n <= -33 -> {
      let unsigned = 256 + n
      Ok(<<0xd0, unsigned:8>>)
    }

    n if n >= -32_768 && n <= -129 -> {
      let unsigned = 65_536 + n
      let high_byte = unsigned / 256
      let low_byte = unsigned % 256
      Ok(<<0xd1, high_byte:8, low_byte:8>>)
    }

    // int32 format (32-bit signed integers)
    n if n >= -2_147_483_648 && n <= -32_769 -> {
      let unsigned = 4_294_967_296 + n
      let b1 = unsigned / 16_777_216 % 256
      let b2 = unsigned / 65_536 % 256
      let b3 = unsigned / 256 % 256
      let b4 = unsigned % 256
      Ok(<<0xd2, b1:8, b2:8, b3:8, b4:8>>)
    }

    // int64 format (64-bit signed integers)
    // For large negatives that don't fit in int32
    n if n < -2_147_483_648 -> {
      // Calculate bytes for 64-bit representation
      // Calculate as unsigned value (two's complement)
      let unsigned = 18_446_744_073_709_551_616 + n
      let b1 = unsigned / 72_057_594_037_927_936 % 256
      let b2 = unsigned / 281_474_976_710_656 % 256
      let b3 = unsigned / 1_099_511_627_776 % 256
      let b4 = unsigned / 4_294_967_296 % 256
      let b5 = unsigned / 16_777_216 % 256
      let b6 = unsigned / 65_536 % 256
      let b7 = unsigned / 256 % 256
      let b8 = unsigned % 256
      Ok(<<0xd3, b1:8, b2:8, b3:8, b4:8, b5:8, b6:8, b7:8, b8:8>>)
    }

    // int64 format for large positive integers
    n if n > 4_294_967_295 -> {
      let b1 = n / 72_057_594_037_927_936 % 256
      let b2 = n / 281_474_976_710_656 % 256
      let b3 = n / 1_099_511_627_776 % 256
      let b4 = n / 4_294_967_296 % 256
      let b5 = n / 16_777_216 % 256
      let b6 = n / 65_536 % 256
      let b7 = n / 256 % 256
      let b8 = n % 256
      Ok(<<0xd3, b1:8, b2:8, b3:8, b4:8, b5:8, b6:8, b7:8, b8:8>>)
    }

    _ -> Error(Nil)
  }
}

/// Encode a floating-point value into MessagePack format
/// The function returns a Result containing the encoded BitArray or an error.
pub fn float(value: Float) -> Result(BitArray, Nil) {
  Ok(encode_float64(value))
}

/// Encode a string value into MessagePack format
/// The function returns a Result containing the encoded BitArray or an error.
/// The string is encoded as UTF-8.
pub fn string(value: String) -> Result(BitArray, Nil) {
  let bytes = bit_array.from_string(value)
  let size = string.byte_size(value)

  case size {
    n if n <= 31 -> {
      let format = 0xa0 + n
      Ok(bit_array.append(<<format:8>>, bytes))
    }

    n if n <= 255 -> {
      Ok(bit_array.append(<<0xd9, n:8>>, bytes))
    }

    n if n <= 65_535 -> {
      let high_byte = n / 256
      let low_byte = n % 256
      Ok(bit_array.append(<<0xda, high_byte:8, low_byte:8>>, bytes))
    }

    // str 32 format (0xdb): strings up to 2^32-1 bytes
    n -> {
      let b1 = n / 16_777_216 % 256
      let b2 = n / 65_536 % 256
      let b3 = n / 256 % 256
      let b4 = n % 256
      Ok(bit_array.append(<<0xdb, b1:8, b2:8, b3:8, b4:8>>, bytes))
    }
  }
}

/// Encode a binary value into MessagePack format
/// The function returns a Result containing the encoded BitArray or an error.
pub fn binary(value: BitArray) -> Result(BitArray, Nil) {
  let size = bit_array.byte_size(value)

  case size {
    n if n <= 255 -> {
      Ok(bit_array.append(<<0xc4, n:8>>, value))
    }

    n if n <= 65_535 -> {
      let high_byte = n / 256
      let low_byte = n % 256
      Ok(bit_array.append(<<0xc5, high_byte:8, low_byte:8>>, value))
    }

    n -> {
      let b1 = n / 16_777_216 % 256
      let b2 = n / 65_536 % 256
      let b3 = n / 256 % 256
      let b4 = n % 256
      Ok(bit_array.append(<<0xc6, b1:8, b2:8, b3:8, b4:8>>, value))
    }
  }
}

/// Encode an array of values into MessagePack format
/// The function returns a Result containing the encoded BitArray or an error.
pub fn array(values: List(data.Value)) -> Result(BitArray, Nil) {
  let size = list.length(values)

  let header = case size {
    n if n <= 15 -> {
      let format = 0x90 + n
      Ok(<<format:8>>)
    }

    n if n <= 65_535 -> {
      let high_byte = n / 256
      let low_byte = n % 256
      Ok(<<0xdc, high_byte:8, low_byte:8>>)
    }

    n -> {
      let b1 = n / 16_777_216 % 256
      let b2 = n / 65_536 % 256
      let b3 = n / 256 % 256
      let b4 = n % 256
      Ok(<<0xdd, b1:8, b2:8, b3:8, b4:8>>)
    }
  }

  case header {
    Error(e) -> Error(e)
    Ok(header_bytes) -> {
      encode_array_elements(values, header_bytes)
    }
  }
}

// Helper function to encode array elements
fn encode_array_elements(
  elements: List(data.Value),
  acc: BitArray,
) -> Result(BitArray, Nil) {
  case elements {
    [] -> Ok(acc)
    [elem, ..rest] -> {
      // Encode the current element
      case value(elem) {
        Error(e) -> Error(e)
        Ok(encoded_elem) -> {
          // Append to accumulator and continue with rest
          let new_acc = bit_array.append(acc, encoded_elem)
          encode_array_elements(rest, new_acc)
        }
      }
    }
  }
}

/// Encode a map of key-value pairs into MessagePack format
/// The function returns a Result containing the encoded BitArray or an error.
pub fn map(value: dict.Dict(data.Value, data.Value)) -> Result(BitArray, Nil) {
  let size = dict.size(value)

  let header = case size {
    m if m <= 15 -> {
      let format = 0x80 + m
      Ok(<<format:8>>)
    }

    m if m <= 65_535 -> {
      let high_byte = m / 256
      let low_byte = m % 256
      Ok(<<0xde, high_byte:8, low_byte:8>>)
    }

    m -> {
      let b1 = m / 16_777_216 % 256
      let b2 = m / 65_536 % 256
      let b3 = m / 256 % 256
      let b4 = m % 256
      Ok(<<0xdf, b1:8, b2:8, b3:8, b4:8>>)
    }
  }

  case header {
    Error(e) -> Error(e)
    Ok(header_bytes) -> {
      // Recursively encode each key-value pair
      dict.to_list(value)
      |> encode_key_value_pairs(header_bytes)
    }
  }
}

// Helper function to encode a list of key-value pairs
fn encode_key_value_pairs(
  pairs: List(#(data.Value, data.Value)),
  acc: BitArray,
) -> Result(BitArray, Nil) {
  case pairs {
    [] -> Ok(acc)
    [#(key, val), ..rest] -> {
      // Encode the key
      case value(key) {
        Error(e) -> Error(e)
        Ok(encoded_key) -> {
          // Encode the value
          case value(val) {
            Error(e) -> Error(e)
            Ok(encoded_val) -> {
              // Append both to the accumulator and continue with rest
              let new_acc = bit_array.append(acc, encoded_key)
              let new_acc = bit_array.append(new_acc, encoded_val)
              encode_key_value_pairs(rest, new_acc)
            }
          }
        }
      }
    }
  }
}

/// Helper function to encode a single value based on its type
pub fn value(value: data.Value) -> Result(BitArray, Nil) {
  case value {
    data.Nil -> nil()
    data.Boolean(b) -> boolean(b)
    data.Integer(i) -> integer(i)
    data.Float(f) -> float(f)
    data.String(s) -> string(s)
    data.Binary(b) -> binary(b)
    data.Array(a) -> array(a)
    data.Map(m) -> map(m)
    data.Extension(type_id, data) -> extension(type_id, data)
  }
}

/// Encode a MessagePack extension value
/// The function takes a type ID and a BitArray of data, and returns a Result
/// containing the encoded BitArray or an error.
/// The type ID is an integer that identifies the type of extension data.
/// The data is a BitArray representing the extension data.
pub fn extension(type_id: Int, data: BitArray) -> Result(BitArray, Nil) {
  let size = bit_array.byte_size(data)
  case size {
    // fixext 1 format (0xd4): fixed-length extension with 1 byte of data
    1 -> Ok(bit_array.append(<<0xd4, type_id:8>>, data))

    // fixext 2 format (0xd5): fixed-length extension with 2 bytes of data
    2 -> Ok(bit_array.append(<<0xd5, type_id:8>>, data))

    // fixext 4 format (0xd6): fixed-length extension with 4 bytes of data
    4 -> Ok(bit_array.append(<<0xd6, type_id:8>>, data))

    // fixext 8 format (0xd7): fixed-length extension with 8 bytes of data
    8 -> Ok(bit_array.append(<<0xd7, type_id:8>>, data))

    // fixext 16 format (0xd8): fixed-length extension with 16 bytes of data
    16 -> Ok(bit_array.append(<<0xd8, type_id:8>>, data))

    // ext 8 format (0xc7): extension data with up to 255 bytes
    n if n <= 255 -> {
      Ok(bit_array.append(<<0xc7, n:8, type_id:8>>, data))
    }

    // ext 16 format (0xc8): extension data with up to 65535 bytes
    n if n <= 65_535 -> {
      let high_byte = n / 256
      let low_byte = n % 256
      Ok(bit_array.append(<<0xc8, high_byte:8, low_byte:8, type_id:8>>, data))
    }

    // ext 32 format (0xc9): extension data with up to 2^32-1 bytes
    n -> {
      let b1 = n / 16_777_216 % 256
      let b2 = n / 65_536 % 256
      let b3 = n / 256 % 256
      let b4 = n % 256
      Ok(bit_array.append(<<0xc9, b1:8, b2:8, b3:8, b4:8, type_id:8>>, data))
    }
  }
}
