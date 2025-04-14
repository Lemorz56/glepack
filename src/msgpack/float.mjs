export function encodeFloat64(value) {
    const buffer = new ArrayBuffer(9);
    const view = new DataView(buffer);
    
    // Set the format byte
    view.setUint8(0, 0xcb);
    
    // Set the float value
    view.setFloat64(1, value, false); // false = big-endian
    
    return new Uint8Array(buffer);
  }