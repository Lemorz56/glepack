//// This module provides functions to decode MessagePack data

import gleam/bit_array
import gleam/dict
import gleam/list
import msgpack/data
import msgpack/error

/// Decodes a MessagePack value from a BitArray
/// Returns a tuple with the decoded value and the remaining BitArray
///
/// ## Errors
///
/// This function can return the following errors:
/// - `InvalidFormat`: When the input data is not valid MessagePack
/// - `IncompleteData`: When the input data is incomplete and more bytes are needed
/// - `IntegerTooLarge`: When the input contains an integer that is too large for Gleam's Int type
/// - `InvalidUtf8`: When the input contains a string that is not valid UTF-8
/// - `ReservedFormat`: When the input contains a reserved format (0xc1)
/// - `UnknownFormat`: When an unknown format was encountered
/// - `UnsupportedExtension`: When the input contains an extension type that is not supported
pub fn value(
  input: BitArray,
) -> Result(#(data.Value, BitArray), error.DecodeError) {
  case input {
    // nil format (0xc0)
    <<0xc0, rest:bytes>> -> Ok(#(data.Nil, rest))

    <<0xc1, _:bytes>> -> Error(error.ReservedFormat)

    // boolean formats (0xc2, 0xc3)
    <<0xc2, rest:bytes>> -> Ok(#(data.Boolean(False), rest))
    <<0xc3, rest:bytes>> -> Ok(#(data.Boolean(True), rest))

    // bin8 format (0xc4)
    <<0xc4, bin_len:8, rest:bytes>> -> {
      case rest {
        <<bin_data:bytes-size(bin_len), remaining:bytes>> ->
          Ok(#(data.Binary(bin_data), remaining))
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // bin16 format (0xc5)
    <<0xc5, bin_len:16-big, rest:bytes>> -> {
      case rest {
        <<bin_data:bytes-size(bin_len), remaining:bytes>> ->
          Ok(#(data.Binary(bin_data), remaining))
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // bin32 format (0xc6)
    <<0xc6, bin_len:32-big, rest:bytes>> -> {
      case rest {
        <<bin_data:bytes-size(bin_len), remaining:bytes>> ->
          Ok(#(data.Binary(bin_data), remaining))
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // float32 format (0xca)
    <<0xca, bits:32-float-big, rest:bytes>> -> Ok(#(data.Float(bits), rest))
    <<0xca, _:bytes>> -> Error(error.IncompleteData)

    // float64 format (0xcb)
    <<0xcb, bits:64-float-big, rest:bytes>> -> Ok(#(data.Float(bits), rest))
    <<0xcb, _:bytes>> -> Error(error.IncompleteData)

    // uint8 format (0xcc)
    <<0xcc, value:8, rest:bytes>> -> Ok(#(data.Integer(value), rest))
    <<0xcc>> -> Error(error.IncompleteData)

    // uint16 format (0xcd)
    <<0xcd, value:16-big, rest:bytes>> -> Ok(#(data.Integer(value), rest))
    <<0xcd, _:bytes>> -> Error(error.IncompleteData)
    <<0xcd>> -> Error(error.IncompleteData)

    // uint32 format (0xce)
    <<0xce, value:32-big, rest:bytes>> -> Ok(#(data.Integer(value), rest))
    <<0xce, _:bytes>> -> Error(error.IncompleteData)
    <<0xce>> -> Error(error.IncompleteData)

    // uint64 format (0xcf) - limited to max int size by Gleam
    <<0xcf, value:64-big, rest:bytes>> -> {
      // Check if the value is too large for Gleam's Int type
      // This is a very large value, which will definitely overflow Gleam's Int
      case value >= 9_223_372_036_854_775_808 {
        True -> Error(error.IntegerTooLarge)
        False -> Ok(#(data.Integer(value), rest))
      }
    }

    // int8 format (0xd0)
    <<0xd0, value:8-signed-big, rest:bytes>> -> Ok(#(data.Integer(value), rest))

    // int16 format (0xd1)
    <<0xd1, value:16-signed-big, rest:bytes>> ->
      Ok(#(data.Integer(value), rest))

    // int32 format (0xd2)
    <<0xd2, value:32-signed-big, rest:bytes>> ->
      Ok(#(data.Integer(value), rest))

    // int64 format (0xd3) - limited to max int size by Gleam
    <<0xd3, value:64-signed-big, rest:bytes>> ->
      Ok(#(data.Integer(value), rest))

    // fixext1 format (0xd4)
    <<0xd4, type_id:8, data:bytes-size(1), rest:bytes>> ->
      Ok(#(data.Extension(type_id, data), rest))

    // fixext2 format (0xd5)
    <<0xd5, type_id:8, data:bytes-size(2), rest:bytes>> ->
      Ok(#(data.Extension(type_id, data), rest))

    // fixext4 format (0xd6)
    <<0xd6, type_id:8, data:bytes-size(4), rest:bytes>> ->
      Ok(#(data.Extension(type_id, data), rest))

    // fixext8 format (0xd7)
    <<0xd7, type_id:8, data:bytes-size(8), rest:bytes>> ->
      Ok(#(data.Extension(type_id, data), rest))

    // fixext16 format (0xd8)
    <<0xd8, type_id:8, data:bytes-size(16), rest:bytes>> ->
      Ok(#(data.Extension(type_id, data), rest))

    // str8 format (0xd9)
    <<0xd9, str_len:8, rest:bytes>> -> {
      case rest {
        <<str_bytes:bytes-size(str_len), remaining:bytes>> -> {
          case bit_array.to_string(str_bytes) {
            Ok(str) -> Ok(#(data.String(str), remaining))
            Error(_) -> Error(error.InvalidUtf8)
          }
        }
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // str16 format (0xda)
    <<0xda, str_len:16-big, rest:bytes>> -> {
      case rest {
        <<str_bytes:bytes-size(str_len), remaining:bytes>> -> {
          case bit_array.to_string(str_bytes) {
            Ok(str) -> Ok(#(data.String(str), remaining))
            Error(_) -> Error(error.InvalidUtf8)
          }
        }
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // str32 format (0xdb)
    <<0xdb, str_len:32-big, rest:bytes>> -> {
      case rest {
        <<str_bytes:bytes-size(str_len), remaining:bytes>> -> {
          case bit_array.to_string(str_bytes) {
            Ok(str) -> Ok(#(data.String(str), remaining))
            Error(_) -> Error(error.InvalidUtf8)
          }
        }
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // array16 format (0xdc)
    <<0xdc, array_len:16-big, rest:bytes>> -> {
      decode_array(array_len, rest, [])
    }

    // array32 format (0xdd)
    <<0xdd, array_len:32-big, rest:bytes>> -> {
      decode_array(array_len, rest, [])
    }

    // map16 format (0xde)
    <<0xde, map_len:16-big, rest:bytes>> -> {
      decode_map(map_len, rest, dict.new())
    }

    // map32 format (0xdf)
    <<0xdf, map_len:32-big, rest:bytes>> -> {
      decode_map(map_len, rest, dict.new())
    }

    // ext8 format (0xc7)
    <<0xc7, ext_len:8, type_id:8, rest:bytes>> -> {
      case rest {
        <<ext_data:bytes-size(ext_len), remaining:bytes>> ->
          Ok(#(data.Extension(type_id, ext_data), remaining))
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // ext16 format (0xc8)
    <<0xc8, ext_len:16-big, type_id:8, rest:bytes>> -> {
      case rest {
        <<ext_data:bytes-size(ext_len), remaining:bytes>> ->
          Ok(#(data.Extension(type_id, ext_data), remaining))
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // ext32 format (0xc9)
    <<0xc9, ext_len:32-big, type_id:8, rest:bytes>> -> {
      case rest {
        <<ext_data:bytes-size(ext_len), remaining:bytes>> ->
          Ok(#(data.Extension(type_id, ext_data), remaining))
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // positive fixint (0x00 - 0x7f)
    <<format:8, rest:bytes>> if format >= 0 && format <= 0x7f ->
      Ok(#(data.Integer(format), rest))

    // fixmap (0x80 - 0x8f)
    <<format:8, rest:bytes>> if format >= 0x80 && format <= 0x8f -> {
      let map_len = format - 0x80
      decode_map(map_len, rest, dict.new())
    }

    // fixarray (0x90 - 0x9f)
    <<format:8, rest:bytes>> if format >= 0x90 && format <= 0x9f -> {
      let array_len = format - 0x90
      decode_array(array_len, rest, [])
    }

    // fixstr (0xa0 - 0xbf)
    <<format:8, rest:bytes>> if format >= 0xa0 && format <= 0xbf -> {
      let str_len = format - 0xa0
      case rest {
        <<str_bytes:bytes-size(str_len), remaining:bytes>> -> {
          case bit_array.to_string(str_bytes) {
            Ok(str) -> Ok(#(data.String(str), remaining))
            Error(_) -> Error(error.InvalidUtf8)
          }
        }
        _ -> Error(error.IncompleteData)
        // Not enough bytes
      }
    }

    // negative fixint (0xe0 - 0xff)
    <<value:8, rest:bytes>> if value >= 0xe0 && value <= 0xff -> {
      // Convert to signed value (two's complement)
      let int_value = value - 256
      Ok(#(data.Integer(int_value), rest))
    }

    _ -> Error(error.UnknownFormat)
    // Unknown format or not enough data
  }
}

// Helper function to decode arrays
fn decode_array(
  count: Int,
  input: BitArray,
  acc: List(data.Value),
) -> Result(#(data.Value, BitArray), error.DecodeError) {
  case count {
    0 -> Ok(#(data.Array(list.reverse(acc)), input))
    _ -> {
      case value(input) {
        Error(e) -> Error(e)
        Ok(#(item_value, rest)) -> {
          decode_array(count - 1, rest, [item_value, ..acc])
        }
      }
    }
  }
}

// Helper function to decode maps
fn decode_map(
  count: Int,
  input: BitArray,
  acc: dict.Dict(data.Value, data.Value),
) -> Result(#(data.Value, BitArray), error.DecodeError) {
  case count {
    0 -> Ok(#(data.Map(acc), input))
    _ -> {
      // Decode key
      case value(input) {
        Error(e) -> Error(e)
        Ok(#(key, rest1)) -> {
          // Decode value
          case value(rest1) {
            Error(e) -> Error(e)
            Ok(#(val, rest2)) -> {
              let new_acc = dict.insert(acc, key, val)
              decode_map(count - 1, rest2, new_acc)
            }
          }
        }
      }
    }
  }
}
