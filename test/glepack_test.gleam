import gleam/bit_array
import gleam/dict
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import glepack
import glepack/data

pub fn main() {
  gleeunit.main()
}

// Basic packing tests

pub fn test_pack_nil() {
  glepack.pack(data.Nil)
  |> should.equal(Ok(<<0xc0>>))
}

pub fn test_pack_boolean() {
  glepack.pack(data.Boolean(True))
  |> should.equal(Ok(<<0xc3>>))

  glepack.pack(data.Boolean(False))
  |> should.equal(Ok(<<0xc2>>))
}

pub fn test_pack_integer() {
  // Positive fixint (0xxxxxxx) - 0 to 127
  glepack.pack(data.Integer(0))
  |> should.equal(Ok(<<0x00>>))

  glepack.pack(data.Integer(127))
  |> should.equal(Ok(<<0x7f>>))

  // uint 8 (0xcc) - 0 to 255
  glepack.pack(data.Integer(128))
  |> should.equal(Ok(<<0xcc, 128>>))

  glepack.pack(data.Integer(255))
  |> should.equal(Ok(<<0xcc, 255>>))

  // uint 16 (0xcd) - 256 to 65535
  glepack.pack(data.Integer(256))
  |> should.equal(Ok(<<0xcd, 1, 0>>))
}

pub fn test_pack_string() {
  // fixstr (101xxxxx) - up to 31 bytes
  glepack.pack(data.String("hello"))
  |> should.equal(Ok(<<0xa5, 104, 101, 108, 108, 111>>))

  // str 8 (0xd9) - up to 255 bytes
  let long_string = "a" |> string.repeat(32)
  let packed = glepack.pack(data.String(long_string))

  case packed {
    Ok(binary) -> {
      bit_array.byte_size(binary) |> should.equal(34)
      // 2 bytes header + 32 bytes content
      bit_array.slice(binary, 0, 1) |> should.equal(Ok(<<0xd9>>))
      bit_array.slice(binary, 1, 1) |> should.equal(Ok(<<32>>))
    }
    Error(_) -> should.fail()
  }
}

pub fn test_pack_array() {
  // Empty array (fixarray, 1001xxxx)
  glepack.pack(data.Array([]))
  |> should.equal(Ok(<<0x90>>))

  // Array with elements
  let array = [data.Integer(1), data.String("test"), data.Boolean(True)]
  let packed = glepack.pack(data.Array(array))

  case packed {
    Ok(binary) -> {
      bit_array.byte_size(binary) |> should.equal(9)
      // 1 byte header + 8 bytes content
      bit_array.slice(binary, 0, 1) |> should.equal(Ok(<<0x93>>))
      // array of 3 elements
    }
    Error(_) -> should.fail()
  }
}

pub fn test_pack_map() {
  // Empty map (fixmap, 1000xxxx)
  glepack.pack(data.Map(dict.new()))
  |> should.equal(Ok(<<0x80>>))

  // Map with elements
  let map =
    dict.new()
    |> dict.insert(data.String("key"), data.String("value"))

  let packed = glepack.pack(data.Map(map))

  case packed {
    Ok(binary) -> {
      bit_array.slice(binary, 0, 1) |> should.equal(Ok(<<0x81>>))
      // map with 1 key-value pair
    }
    Error(_) -> should.fail()
  }
}

// Basic unpacking tests

pub fn test_unpack_nil() {
  glepack.unpack(<<0xc0>>)
  |> should.equal(Ok(#(data.Nil, <<>>)))
}

pub fn test_unpack_boolean() {
  glepack.unpack(<<0xc3>>)
  |> should.equal(Ok(#(data.Boolean(True), <<>>)))

  glepack.unpack(<<0xc2>>)
  |> should.equal(Ok(#(data.Boolean(False), <<>>)))
}

pub fn test_unpack_integer() {
  // Positive fixint
  glepack.unpack(<<0x00>>)
  |> should.equal(Ok(#(data.Integer(0), <<>>)))

  glepack.unpack(<<0x7f>>)
  |> should.equal(Ok(#(data.Integer(127), <<>>)))

  // uint 8
  glepack.unpack(<<0xcc, 0xff>>)
  |> should.equal(Ok(#(data.Integer(255), <<>>)))

  // uint 16
  glepack.unpack(<<0xcd, 0x01, 0x00>>)
  |> should.equal(Ok(#(data.Integer(256), <<>>)))
}

pub fn test_unpack_string() {
  // fixstr
  glepack.unpack(<<0xa5, 104, 101, 108, 108, 111>>)
  |> should.equal(Ok(#(data.String("hello"), <<>>)))
}

// Round trip tests

pub fn test_round_trip_primitive() {
  let values = [
    data.Nil,
    data.Boolean(True),
    data.Boolean(False),
    data.Integer(42),
    data.String("hello world"),
  ]

  // Test each value can be packed and then unpacked
  list.each(values, fn(value) {
    let packed = glepack.pack_strict(value)
    let unpacked = glepack.unpack_exact_strict(packed)
    unpacked |> should.equal(value)
  })
}

pub fn test_round_trip_nested() {
  // Create a nested structure with map, array, and various data types
  let inner_map =
    dict.new()
    |> dict.insert(data.String("key1"), data.Integer(42))
    |> dict.insert(data.String("key2"), data.Boolean(True))

  let array =
    data.Array([data.String("item1"), data.Integer(99), data.Map(inner_map)])

  let outer_map =
    dict.new()
    |> dict.insert(data.String("array"), array)
    |> dict.insert(data.String("nil"), data.Nil)

  let original = data.Map(outer_map)

  // Pack and then unpack
  let packed = glepack.pack_strict(original)
  let unpacked = glepack.unpack_exact_strict(packed)

  // Verify it roundtrips correctly
  unpacked |> should.equal(original)
}

pub fn test_unpack_exact() {
  // Complete input with no trailing bytes
  glepack.unpack_exact(<<0xc3>>)
  |> should.equal(Ok(data.Boolean(True)))

  // Input with trailing bytes should fail
  glepack.unpack_exact(<<0xc3, 0xc0>>)
  |> should.be_error
}

pub fn test_strict_functions() {
  // pack_strict works for valid data
  glepack.pack_strict(data.Integer(42))
  |> bit_array.byte_size
  |> should.equal(1)

  // unpack_strict works for valid data
  glepack.unpack_strict(<<0xa5, 104, 101, 108, 108, 111>>)
  |> should.equal(#(data.String("hello"), <<>>))

  // unpack_exact_strict works for valid data
  glepack.unpack_exact_strict(<<0xa5, 104, 101, 108, 108, 111>>)
  |> should.equal(data.String("hello"))
}
