import gleam/bit_array
import gleam/result
import gleeunit/should
import glepack/data
import glepack/decode
import glepack/encode

pub fn extension_encoding_test() {
  // fixext 1 - extension with 1 byte of data
  encode.extension(1, <<5>>)
  |> should.equal(Ok(<<0xd4, 1, 5>>))

  // fixext 2 - extension with 2 bytes of data
  encode.extension(2, <<1, 2>>)
  |> should.equal(Ok(<<0xd5, 2, 1, 2>>))

  // fixext 4 - extension with 4 bytes of data
  encode.extension(3, <<1, 2, 3, 4>>)
  |> should.equal(Ok(<<0xd6, 3, 1, 2, 3, 4>>))

  // fixext 8 - extension with 8 bytes of data
  encode.extension(4, <<1, 2, 3, 4, 5, 6, 7, 8>>)
  |> should.equal(Ok(<<0xd7, 4, 1, 2, 3, 4, 5, 6, 7, 8>>))

  // fixext 16 - extension with 16 bytes of data
  encode.extension(5, <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>)
  |> should.equal(
    Ok(<<0xd8, 5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>),
  )

  // ext 8 - extension with 3 bytes (arbitrary size up to 255 bytes)
  encode.extension(6, <<1, 2, 3>>)
  |> should.equal(Ok(<<0xc7, 3, 6, 1, 2, 3>>))

  // ext 16 - extension with data that would use ext 16 format
  // Create a 17-byte binary
  let data_17_bytes =
    bit_array.append(<<1, 2, 3, 4, 5, 6, 7, 8>>, <<
      9, 10, 11, 12, 13, 14, 15, 16, 17,
    >>)

  let result = encode.extension(7, data_17_bytes)
  result
  |> should.be_ok()

  case result {
    Ok(bits) -> {
      // Should start with ext8 marker (0xc7) followed by length 17 (decimal) and type ID 7
      let header = bit_array.slice(from: bits, at: 0, take: 3)
      should.equal(header, Ok(<<0xc7, 17, 7>>))
    }
    Error(_) -> should.fail()
  }

  // Check that encode.value works with extension types
  encode.value(data.Extension(8, <<1, 2>>))
  |> should.equal(Ok(<<0xd5, 8, 1, 2>>))
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

pub fn roundtrip_extension_test() {
  // Test that encoding and then decoding an extension value returns the original value
  let ext_value = data.Extension(42, <<1, 2, 3, 4>>)

  let result =
    encode.value(ext_value)
    |> result.then(fn(encoded) {
      decode.value(encoded)
      |> result.map_error(fn(_) { Nil })
    })

  case result {
    Ok(#(decoded, _)) -> should.equal(decoded, ext_value)
    Error(_) -> should.fail()
  }

  // Test a larger extension value
  let large_data =
    bit_array.append(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>, <<
      17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    >>)
  let large_ext_value = data.Extension(99, large_data)

  let large_result =
    encode.value(large_ext_value)
    |> result.then(fn(encoded) {
      decode.value(encoded)
      |> result.map_error(fn(_) { Nil })
    })

  case large_result {
    Ok(#(decoded, _)) -> should.equal(decoded, large_ext_value)
    Error(_) -> should.fail()
  }
}
