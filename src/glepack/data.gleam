//// This module contains the data types used in MessagePack encoding and decoding

import gleam/dict.{type Dict}

/// Represents a MessagePack value
pub type Value {
  /// Represents the nil value
  Nil

  /// Represents a boolean value
  Boolean(Bool)

  /// Represents an integer value
  Integer(Int)

  /// Represents a floating-point value
  Float(Float)

  /// Represents a UTF-8 string
  String(String)

  /// Represents binary data
  Binary(BitArray)

  /// Represents an array of values
  Array(List(Value))

  /// Represents a map of key-value pairs
  Map(Dict(Value, Value))

  /// Represents an extension value with a type ID and data
  Extension(Int, BitArray)
}
