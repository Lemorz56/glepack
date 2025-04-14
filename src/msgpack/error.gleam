//// This module contains the error types used in MessagePack encoding and decoding

import gleam/int

/// Errors that can occur when decoding MessagePack data.
/// 
/// This type provides specific error cases to help with debugging and
/// proper error handling when working with MessagePack data.
/// 
/// ## Example Usage
/// 
/// ```gleam
/// import msgpack/decode
/// import msgpack/error
/// 
/// pub fn handle_decode(data: BitArray) {
///   case decode.value(data) {
///     Ok(value) -> // Handle success case
///     Error(error.IncompleteData)
///     Error(error.InvalidUtf8)
///     Error(error.IntegerTooLarge)
///     Error(_) -> // Handle other errors
///   }
/// }
/// ```
pub type DecodeError {
  /// The input data is not valid MessagePack
  InvalidFormat

  /// The input data is incomplete and more bytes are needed
  IncompleteData

  /// The input contains an integer that is too large for Gleam's Int type
  IntegerTooLarge

  /// The input contains a string that is not valid UTF-8
  InvalidUtf8

  /// The input contains a reserved format (0xc1)
  ReservedFormat

  /// An unknown format was encountered
  UnknownFormat

  /// An extension type that is not supported by the decoder
  UnsupportedExtension(type_id: Int)
}

/// Converts a DecodeError to a human-readable string
pub fn to_string(error: DecodeError) -> String {
  case error {
    InvalidFormat -> "Invalid MessagePack format"
    IncompleteData -> "Incomplete MessagePack data, more bytes needed"
    IntegerTooLarge -> "Integer too large for Gleam's Int type"
    InvalidUtf8 -> "Invalid UTF-8 string data"
    ReservedFormat -> "Reserved MessagePack format (0xc1) encountered"
    UnknownFormat -> "Unknown MessagePack format encountered"
    UnsupportedExtension(type_id) ->
      "Unsupported extension type: " <> int.to_string(type_id)
  }
}
