# GlePack

[![Package Version](https://img.shields.io/hexpm/v/glepack)](https://hex.pm/packages/glepack)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glepack/)

A complete [MessagePack](https://msgpack.org/) serialization library for the Gleam programming language.

GlePack allows you to encode Gleam values to MessagePack binary format and decode MessagePack binary data back to Gleam values.

Documentation can be found at <https://hexdocs.pm/glepack>.

## Installation

```shell
gleam add glepack
```

## Basic Usage

```gleam
import gleam/dict
import glepack
import msgpack/data

pub fn main() {
  // Encode a value, returning a Result
  glepack.pack(data.Integer(42))
  // -> Ok(<<42>>)

  // Decode a value, returning the value and remaining bytes
  let data = data.String("hello")
  glepack.unpack(data)
  // -> Ok(#(data.String("hello"), <<>>))

  // Using the strict versions when you're confident the data is valid

  // Encode a value, panicking on failure
  glepack.pack_strict(data.Integer(42))
  // -> <<42>>

  // Decode a value, panicking on failure
  glepack.unpack_strict(data)
  // -> #(data.String("hello"), <<>>)
  
  // Working with maps
  let map = dict.new()
    |> dict.insert(data.String("key"), data.String("value"))
  
  let packed = glepack.pack_strict(data.Map(map))
  let unpacked = glepack.unpack_exact_strict(packed)
  // -> data.Map containing our key-value pair
}
```


### Reading MessagePack data from a file

```gleam
pub fn read_msgpack_config() {
  use ok(content) <- result.try(file.read("config.msgpack"))
  
  // Decode the entire file as a single MessagePack value with no remaining bytes
  case glepack.unpack_exact(content) {
    Ok(config) -> {
      // Use the config
      Ok(config)
    }
    Error(err) -> Error("Invalid config file: " <> error.to_string(err))
  }
}
```

### Strict unpack & Exact

```gleam
// Using the strict versions when you're confident the data is valid
pub fn process_trusted_msgpack(data: BitArray) -> data.Value {
  // This will panic if data isn't valid MessagePack
  let #(value, _) = glepack.unpack_strict(data)
  
  // Do something with the value
  value
}

// When you expect exactly one complete MessagePack value
pub fn parse_complete_msgpack(data: BitArray) -> data.Value {
  // This will panic if data isn't valid or has trailing bytes
  glepack.unpack_exact_strict(data)
}
```

## Supported Types

GlePack supports all MessagePack types:

| MessagePack Type | Gleam Type |
|-----------------|------------|
| nil | `data.Nil` |
| boolean | `data.Boolean(Bool)` |
| integer | `data.Integer(Int)` |
| float | `data.Float(Float)` |
| string | `data.String(String)` |
| binary | `data.Binary(BitArray)` |
| array | `data.Array(List(Value))` |
| map | `data.Map(Dict(Value, Value))` |
| extension | `data.Extension(Int, BitArray)` |

## API

GlePack provides several functions for encoding and decoding:

### Encoding

```gleam
// Encode a value, returning a Result
glepack.pack(data.Integer(42))
// -> Ok(<<42>>)

// Encode a value, panicking on failure
glepack.pack_strict(data.Integer(42))
// -> <<42>>
```

### Decoding

```gleam
// Decode a value, returning the value and remaining bytes
let data = data.String("hello")
glepack.unpack(data)
// -> Ok(#(data.String("hello"), <<>>))

// Decode a value, panicking on failure
glepack.unpack_strict(data)
// -> #(data.String("hello"), <<>>)
  
  // Decode a value, ensuring no trailing bytes remain
glepack.unpack_exact(data)
// -> Ok(data.String("hello"))

// Decode a value with no trailing bytes, panicking on failure
glepack.unpack_exact_strict(data)
// -> data.String("hello")
```

## Working with Complex Types

### Arrays

```gleam
import glepack
import msgpack/data

pub fn encode_array() {
  // Create an array with different value types
  let array = [data.Integer(1), data.String("test"), data.Boolean(True)]
  
  // Pack the array
  glepack.pack(data.Array(array))
  // -> Ok(<<0x93, 1, 0xa4, 116, 101, 115, 116, 0xc3>>)
}
```

### Maps

```gleam
import gleam/dict
import glepack
import msgpack/data

pub fn encode_map() {
  // Create a map
  let map = dict.new()
    |> dict.insert(data.String("a"), data.Integer(1))
    |> dict.insert(data.String("b"), data.Integer(2))
  
  // Pack the map
  glepack.pack(data.Map(map))
  // -> Ok binary representing the map
}
```

### Extensions

Extensions are a powerful feature of MessagePack that allow you to define custom types:

```gleam
import glepack
import msgpack/data
import gleam/bit_array

// Example: Custom timestamp extension
pub type Timestamp {
  Timestamp(seconds: Int, nanoseconds: Int)
}

// Extension type ID for timestamp (MessagePack spec reserves -1)
const timestamp_type_id = -1

// Encode a timestamp to an extension
pub fn encode_timestamp(ts: Timestamp) -> data.Value {
  // Pack timestamp in MessagePack timestamp format
  let data = bit_array.append(
    <<ts.seconds:64-signed-big>>,
    <<ts.nanoseconds:32-unsigned-big>>
  )
  
  // Create an extension value
  data.Extension(timestamp_type_id, data)
}

// Decode an extension to a timestamp
pub fn decode_timestamp(value: data.Value) -> Result(Timestamp, String) {
  case value {
    data.Extension(ext_type, data) if ext_type == timestamp_type_id -> {
      case data {
        <<seconds:64-signed-big, nanos:32-unsigned-big>> -> {
          Ok(Timestamp(seconds: seconds, nanoseconds: nanos))
        }
        _ -> Error("Invalid timestamp format")
      }
    }
    _ -> Error("Not a timestamp extension")
  }
}

pub fn timestamp_example() {
  // Create a timestamp
  let now = Timestamp(seconds: 1681489200, nanoseconds: 123_456_789)
  
  // Convert to MessagePack extension
  let ext = encode_timestamp(now)
  
  // Pack the extension
  let packed = glepack.pack_strict(ext)
  
  // Later, unpack the data
  let unpacked = glepack.unpack_exact_strict(packed)
  
  // Convert back to a timestamp
  let original = decode_timestamp(unpacked)
  // original == Ok(Timestamp(seconds: 1681489200, nanoseconds: 123_456_789))
}
```

## Nested Data Structures

GlePack handles complex nested data:

```gleam
import gleam/dict
import glepack
import msgpack/data

pub fn handle_nested_data() {
  // Create a nested structure with map, array, and various data types
  let inner_map = dict.new()
    |> dict.insert(data.String("key1"), data.Integer(42))
    |> dict.insert(data.String("key2"), data.Boolean(True))

  let array = data.Array([
    data.String("item1"), 
    data.Integer(99), 
    data.Map(inner_map)
  ])

  let outer_map = dict.new()
    |> dict.insert(data.String("array"), array)
    |> dict.insert(data.String("nil"), data.Nil)

  let original = data.Map(outer_map)
  
  // Pack the data - in a real application, this would be sent over 
  // the network or stored in a database
  let packed = glepack.pack_strict(original)
  
  // Later, we receive or read this data back
  let unpacked = glepack.unpack_exact_strict(packed)
  
  // Unpacked now contains our original nested data structure
}
```

## Error Handling

GlePack provides detailed error information when decoding fails:

```gleam
import gleam/bit_array
import gleam/result
import glepack
import msgpack/error

pub fn handle_errors() {
  // Let's say we received some MessagePack data from an external source
  let received_data = get_external_data()
  
  // Decoding with proper error handling
  case glepack.unpack_exact(received_data) {
    Ok(value) -> {
      // Successfully decoded the value
      process_value(value)
    }
    Error(error.IncompleteData) -> {
      // The data was truncated or has trailing bytes
    }
    Error(error.InvalidUtf8) -> {
      // A string in the MessagePack data contains invalid UTF-8
    }
    Error(error.IntegerTooLarge) -> {
      // An integer value is too large for Gleam's Int type
    }
    Error(_) -> {
      // Other errors: UnknownFormat, ReservedFormat, etc.
    }
  }
}
```

## Development

```sh
gleam test  # Run the tests
```

## License

GlePack is licensed under the Apache-2.0 license.
