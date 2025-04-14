-module(float).
-export([encode_float64/1]).

% Encode a float as MessagePack float64 format (0xcb followed by 8 bytes in big-endian)
encode_float64(Value) ->
    % IEEE 754 double-precision binary representation
    Bin = <<Value:64/float>>,
    % Prepend the MessagePack format byte 0xcb for float64
    <<16#cb, Bin/binary>>.