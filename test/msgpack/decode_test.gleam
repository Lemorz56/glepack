import gleam/dict
import gleam/list
import gleeunit/should
import glepack/data
import glepack/decode
import glepack/error

pub fn nil_decoding_test() {
  decode.value(<<0xc0>>)
  |> should.equal(Ok(#(data.Nil, <<>>)))
}

pub fn boolean_decoding_test() {
  decode.value(<<0xc2>>)
  |> should.equal(Ok(#(data.Boolean(False), <<>>)))

  decode.value(<<0xc3>>)
  |> should.equal(Ok(#(data.Boolean(True), <<>>)))
}

pub fn integer_decoding_test() {
  // positive fixint (0x00 - 0x7f)
  decode.value(<<0>>)
  |> should.equal(Ok(#(data.Integer(0), <<>>)))

  decode.value(<<127>>)
  |> should.equal(Ok(#(data.Integer(127), <<>>)))

  // negative fixint (0xe0 - 0xff)
  decode.value(<<224>>)
  |> should.equal(Ok(#(data.Integer(-32), <<>>)))

  decode.value(<<255>>)
  |> should.equal(Ok(#(data.Integer(-1), <<>>)))

  // uint8 (0xcc)
  decode.value(<<0xcc, 128>>)
  |> should.equal(Ok(#(data.Integer(128), <<>>)))

  decode.value(<<0xcc, 255>>)
  |> should.equal(Ok(#(data.Integer(255), <<>>)))

  // uint16 (0xcd)
  decode.value(<<0xcd, 1, 0>>)
  |> should.equal(Ok(#(data.Integer(256), <<>>)))

  decode.value(<<0xcd, 255, 255>>)
  |> should.equal(Ok(#(data.Integer(65_535), <<>>)))

  // uint32 (0xce)
  decode.value(<<0xce, 0, 1, 0, 0>>)
  |> should.equal(Ok(#(data.Integer(65_536), <<>>)))

  // int8 (0xd0)
  decode.value(<<0xd0, 223>>)
  |> should.equal(Ok(#(data.Integer(-33), <<>>)))

  decode.value(<<0xd0, 128>>)
  |> should.equal(Ok(#(data.Integer(-128), <<>>)))

  // int16 (0xd1)
  decode.value(<<0xd1, 255, 127>>)
  |> should.equal(Ok(#(data.Integer(-129), <<>>)))

  decode.value(<<0xd1, 128, 0>>)
  |> should.equal(Ok(#(data.Integer(-32_768), <<>>)))
}

pub fn float_decoding_test() {
  decode.value(<<0xcb, 0, 0, 0, 0, 0, 0, 0, 0>>)
  |> should.equal(Ok(#(data.Float(0.0), <<>>)))

  decode.value(<<0xcb, 63, 240, 0, 0, 0, 0, 0, 0>>)
  |> should.equal(Ok(#(data.Float(1.0), <<>>)))

  decode.value(<<0xcb, 191, 240, 0, 0, 0, 0, 0, 0>>)
  |> should.equal(Ok(#(data.Float(-1.0), <<>>)))

  decode.value(<<0xcb, 64, 9, 33, 249, 240, 27, 134, 110>>)
  |> should.equal(Ok(#(data.Float(3.14159), <<>>)))
}

pub fn string_decoding_test() {
  // Empty string (fixstr format)
  decode.value(<<0xa0>>)
  |> should.equal(Ok(#(data.String(""), <<>>)))

  // Short string (fixstr format)
  decode.value(<<0xa5, 104, 101, 108, 108, 111>>)
  |> should.equal(Ok(#(data.String("hello"), <<>>)))

  // String with exactly 31 bytes (maximum for fixstr)
  let str31 = <<
    0xbf, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 49, 50, 51, 52, 53, 54, 55, 56,
    57, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 49,
  >>
  decode.value(str31)
  |> should.equal(Ok(#(data.String("1234567890123456789012345678901"), <<>>)))

  // String with 32 bytes (str 8 format)
  let str32 = <<
    0xd9, 32, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 49, 50, 51, 52, 53, 54, 55,
    56, 57, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 49, 50,
  >>
  decode.value(str32)
  |> should.equal(Ok(#(data.String("12345678901234567890123456789012"), <<>>)))
}

pub fn binary_decoding_test() {
  // Empty binary (bin 8 format)
  decode.value(<<0xc4, 0>>)
  |> should.equal(Ok(#(data.Binary(<<>>), <<>>)))

  // Small binary (bin 8 format)
  decode.value(<<0xc4, 5, 1, 2, 3, 4, 5>>)
  |> should.equal(Ok(#(data.Binary(<<1, 2, 3, 4, 5>>), <<>>)))
}

pub fn array_decoding_test() {
  // Empty array (fixarray format)
  decode.value(<<0x90>>)
  |> should.equal(Ok(#(data.Array([]), <<>>)))

  // Small array (fixarray format)
  decode.value(<<0x93, 1, 2, 3>>)
  |> should.equal(
    Ok(#(data.Array([data.Integer(1), data.Integer(2), data.Integer(3)]), <<>>)),
  )

  // Array with 15 elements (maximum for fixarray)
  let arr15 = <<0x9f, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  decode.value(arr15)
  |> should.equal(Ok(#(data.Array(list.repeat(data.Integer(0), 15)), <<>>)))
}

pub fn map_decoding_test() {
  // Empty map (fixmap format)
  decode.value(<<0x80>>)
  |> should.equal(Ok(#(data.Map(dict.new()), <<>>)))

  // Small map (fixmap format) with key "a": 1, "b": 2
  let map_data = <<0x82, 0xa1, 97, 1, 0xa1, 98, 2>>
  let map =
    dict.new()
    |> dict.insert(data.String("a"), data.Integer(1))
    |> dict.insert(data.String("b"), data.Integer(2))

  decode.value(map_data)
  |> should.equal(Ok(#(data.Map(map), <<>>)))
}

pub fn extension_decoding_test() {
  // fixext 1
  decode.value(<<0xd4, 1, 5>>)
  |> should.equal(Ok(#(data.Extension(1, <<5>>), <<>>)))

  // fixext 2
  decode.value(<<0xd5, 2, 1, 2>>)
  |> should.equal(Ok(#(data.Extension(2, <<1, 2>>), <<>>)))

  // fixext 4
  decode.value(<<0xd6, 3, 1, 2, 3, 4>>)
  |> should.equal(Ok(#(data.Extension(3, <<1, 2, 3, 4>>), <<>>)))

  // fixext 8
  decode.value(<<0xd7, 4, 1, 2, 3, 4, 5, 6, 7, 8>>)
  |> should.equal(Ok(#(data.Extension(4, <<1, 2, 3, 4, 5, 6, 7, 8>>), <<>>)))

  // fixext 16
  decode.value(<<
    0xd8, 5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
  >>)
  |> should.equal(
    Ok(
      #(
        data.Extension(5, <<
          1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        >>),
        <<>>,
      ),
    ),
  )

  // ext 8 (with a small payload)
  decode.value(<<0xc7, 3, 6, 1, 2, 3>>)
  |> should.equal(Ok(#(data.Extension(6, <<1, 2, 3>>), <<>>)))

  // ext 16 (with a small payload)
  decode.value(<<0xc8, 0, 4, 7, 1, 2, 3, 4>>)
  |> should.equal(Ok(#(data.Extension(7, <<1, 2, 3, 4>>), <<>>)))

  // ext 32 (with a small payload)
  decode.value(<<0xc9, 0, 0, 0, 5, 8, 1, 2, 3, 4, 5>>)
  |> should.equal(Ok(#(data.Extension(8, <<1, 2, 3, 4, 5>>), <<>>)))
}

pub fn remainder_test() {
  // Test that the decoder correctly returns the remainder
  decode.value(<<0xc0, 0xc2>>)
  |> should.equal(Ok(#(data.Nil, <<0xc2>>)))

  decode.value(<<0xa5, 104, 101, 108, 108, 111, 0xc3>>)
  |> should.equal(Ok(#(data.String("hello"), <<0xc3>>)))
}

pub fn error_test() {
  // Reserved format byte (0xc1)
  decode.value(<<0xc1>>)
  |> should.equal(Error(error.ReservedFormat))

  // Truncated input for uint8 format
  decode.value(<<0xcc>>)
  |> should.equal(Error(error.IncompleteData))

  // String with missing characters
  decode.value(<<0xa5, 104, 101, 108, 108>>)
  |> should.equal(Error(error.IncompleteData))

  // Test invalid UTF-8 string
  decode.value(<<0xa2, 0xFF, 0xFE>>)
  |> should.equal(Error(error.InvalidUtf8))

  // Test integer too large
  decode.value(<<0xcf, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>)
  |> should.equal(Error(error.IntegerTooLarge))

  // Unknown format - using 0xC1 followed by an additional byte, which is not a valid MessagePack format
  decode.value(<<0xd3, 0xFF>>)
  |> should.equal(Error(error.UnknownFormat))
}
