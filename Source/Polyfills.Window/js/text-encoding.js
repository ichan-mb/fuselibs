/**
 * TextEncoder and TextDecoder Polyfill for Fuse
 *
 * Provides comprehensive text encoding/decoding functionality for environments
 * that don't have native TextEncoder/TextDecoder support.
 *
 * Based on the Encoding Living Standard:
 * https://encoding.spec.whatwg.org/
 *
 * @preserve-header
 */

(function(self) {
  'use strict';

  // Check if native implementations exist
  var nativeTextEncoder = self.TextEncoder;
  var nativeTextDecoder = self.TextDecoder;

  // Utility functions
  function stringFromCharCode(bytes) {
    var chars = [];
    for (var i = 0; i < bytes.length; i++) {
      chars.push(String.fromCharCode(bytes[i]));
    }
    return chars.join('');
  }

  function codePointsToString(codePoints) {
    var result = '';
    for (var i = 0; i < codePoints.length; i++) {
      var codePoint = codePoints[i];
      if (codePoint <= 0xFFFF) {
        result += String.fromCharCode(codePoint);
      } else {
        // Surrogate pair
        codePoint -= 0x10000;
        result += String.fromCharCode(
          0xD800 + (codePoint >> 10),
          0xDC00 + (codePoint & 0x3FF)
        );
      }
    }
    return result;
  }

  // TextEncoder Implementation
  function TextEncoder(encoding) {
    // Only UTF-8 is required by spec, but we'll be flexible
    this.encoding = (encoding || 'utf-8').toLowerCase();

    if (this.encoding !== 'utf-8' && this.encoding !== 'utf8') {
      throw new RangeError('TextEncoder only supports utf-8 encoding');
    }
  }

  TextEncoder.prototype.encode = function(input) {
    if (input === undefined || input === null) {
      input = '';
    }

    var str = String(input);
    var result = [];

    for (var i = 0; i < str.length; i++) {
      var codePoint = str.codePointAt ? str.codePointAt(i) : getCodePoint(str, i);

      if (codePoint < 0x80) {
        // 1-byte sequence
        result.push(codePoint);
      } else if (codePoint < 0x800) {
        // 2-byte sequence
        result.push(
          0xC0 | (codePoint >> 6),
          0x80 | (codePoint & 0x3F)
        );
      } else if (codePoint < 0x10000) {
        // 3-byte sequence
        result.push(
          0xE0 | (codePoint >> 12),
          0x80 | ((codePoint >> 6) & 0x3F),
          0x80 | (codePoint & 0x3F)
        );
      } else {
        // 4-byte sequence
        result.push(
          0xF0 | (codePoint >> 18),
          0x80 | ((codePoint >> 12) & 0x3F),
          0x80 | ((codePoint >> 6) & 0x3F),
          0x80 | (codePoint & 0x3F)
        );
        // Skip the next character if it's a surrogate pair
        if (str.charCodeAt(i) >= 0xD800 && str.charCodeAt(i) <= 0xDBFF) {
          i++;
        }
      }
    }

    return new Uint8Array(result);
  };

  // Helper function to get code point (for older browsers)
  function getCodePoint(str, i) {
    var code = str.charCodeAt(i);

    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < str.length) {
      var next = str.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        return 0x10000 + ((code - 0xD800) << 10) + (next - 0xDC00);
      }
    }

    return code;
  }

  // TextDecoder Implementation
  function TextDecoder(encoding, options) {
    this.encoding = normalizeEncoding(encoding || 'utf-8');
    this.fatal = !!(options && options.fatal);
    this.ignoreBOM = !!(options && options.ignoreBOM);

    // State for streaming
    this._decoder = createDecoder(this.encoding);
  }

  function normalizeEncoding(encoding) {
    var normalized = String(encoding).toLowerCase().replace(/[-_]/g, '');

    // Map common aliases
    var aliases = {
      'utf8': 'utf-8',
      'unicode11utf8': 'utf-8',
      'utf16le': 'utf-16le',
      'utf16be': 'utf-16be',
      'utf16': 'utf-16le', // Default to little-endian
      'iso88591': 'latin1',
      'latin1': 'latin1',
      'ascii': 'ascii',
      'usascii': 'ascii'
    };

    return aliases[normalized] || normalized;
  }

  function createDecoder(encoding) {
    switch (encoding) {
      case 'utf-8':
        return new UTF8Decoder();
      case 'utf-16le':
        return new UTF16LEDecoder();
      case 'utf-16be':
        return new UTF16BEDecoder();
      case 'latin1':
        return new Latin1Decoder();
      case 'ascii':
        return new ASCIIDecoder();
      default:
        throw new RangeError('Unsupported encoding: ' + encoding);
    }
  }

  TextDecoder.prototype.decode = function(input, options) {
    var stream = !!(options && options.stream);
    var bytes;

    if (input === undefined) {
      bytes = new Uint8Array(0);
    } else if (input instanceof ArrayBuffer) {
      bytes = new Uint8Array(input);
    } else if (input.buffer instanceof ArrayBuffer) {
      bytes = new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
    } else {
      throw new TypeError('Input must be an ArrayBuffer or ArrayBufferView');
    }

    return this._decoder.decode(bytes, stream, this.fatal);
  };

  // UTF-8 Decoder
  function UTF8Decoder() {
    this.buffer = [];
    this.needed = 0;
    this.codePoint = 0;
  }

  UTF8Decoder.prototype.decode = function(bytes, stream, fatal) {
    var result = [];
    var i = 0;

    while (i < bytes.length) {
      var byte = bytes[i++];

      if (this.needed === 0) {
        if (byte < 0x80) {
          result.push(byte);
        } else if ((byte & 0xE0) === 0xC0) {
          this.needed = 1;
          this.codePoint = byte & 0x1F;
        } else if ((byte & 0xF0) === 0xE0) {
          this.needed = 2;
          this.codePoint = byte & 0x0F;
        } else if ((byte & 0xF8) === 0xF0) {
          this.needed = 3;
          this.codePoint = byte & 0x07;
        } else {
          if (fatal) throw new Error('Invalid UTF-8 sequence');
          result.push(0xFFFD); // Replacement character
        }
      } else {
        if ((byte & 0xC0) === 0x80) {
          this.codePoint = (this.codePoint << 6) | (byte & 0x3F);
          this.needed--;

          if (this.needed === 0) {
            if (this.codePoint > 0x10FFFF ||
                (this.codePoint >= 0xD800 && this.codePoint <= 0xDFFF)) {
              if (fatal) throw new Error('Invalid UTF-8 code point');
              result.push(0xFFFD);
            } else {
              result.push(this.codePoint);
            }
            this.codePoint = 0;
          }
        } else {
          if (fatal) throw new Error('Invalid UTF-8 continuation byte');
          result.push(0xFFFD);
          this.needed = 0;
          this.codePoint = 0;
          i--; // Reprocess this byte
        }
      }
    }

    // Handle incomplete sequences
    if (!stream && this.needed > 0) {
      if (fatal) throw new Error('Incomplete UTF-8 sequence');
      result.push(0xFFFD);
      this.needed = 0;
      this.codePoint = 0;
    }

    return codePointsToString(result);
  };

  // UTF-16 Little Endian Decoder
  function UTF16LEDecoder() {
    this.leadSurrogate = null;
    this.buffer = null;
  }

  UTF16LEDecoder.prototype.decode = function(bytes, stream, fatal) {
    var result = [];
    var i = 0;

    // Handle leftover byte from previous call
    if (this.buffer !== null) {
      if (bytes.length === 0) {
        if (!stream) {
          if (fatal) throw new Error('Incomplete UTF-16 sequence');
          result.push(0xFFFD);
        }
        return codePointsToString(result);
      }

      var codeUnit = this.buffer | (bytes[i++] << 8);
      this.buffer = null;
      this.processCodeUnit(codeUnit, result, fatal);
    }

    while (i < bytes.length - 1) {
      var codeUnit = bytes[i] | (bytes[i + 1] << 8);
      i += 2;
      this.processCodeUnit(codeUnit, result, fatal);
    }

    // Handle trailing byte
    if (i < bytes.length) {
      if (stream) {
        this.buffer = bytes[i];
      } else {
        if (fatal) throw new Error('Incomplete UTF-16 sequence');
        result.push(0xFFFD);
      }
    }

    return codePointsToString(result);
  };

  UTF16LEDecoder.prototype.processCodeUnit = function(codeUnit, result, fatal) {
    if (this.leadSurrogate !== null) {
      var leadSurrogate = this.leadSurrogate;
      this.leadSurrogate = null;

      if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
        result.push(0x10000 + ((leadSurrogate & 0x3FF) << 10) + (codeUnit & 0x3FF));
      } else {
        if (fatal) throw new Error('Invalid UTF-16 surrogate pair');
        result.push(0xFFFD, codeUnit);
      }
    } else if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      this.leadSurrogate = codeUnit;
    } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
      if (fatal) throw new Error('Invalid UTF-16 surrogate');
      result.push(0xFFFD);
    } else {
      result.push(codeUnit);
    }
  };

  // UTF-16 Big Endian Decoder
  function UTF16BEDecoder() {
    UTF16LEDecoder.call(this);
  }

  UTF16BEDecoder.prototype = Object.create(UTF16LEDecoder.prototype);
  UTF16BEDecoder.prototype.constructor = UTF16BEDecoder;

  UTF16BEDecoder.prototype.decode = function(bytes, stream, fatal) {
    var result = [];
    var i = 0;

    // Handle leftover byte from previous call
    if (this.buffer !== null) {
      if (bytes.length === 0) {
        if (!stream) {
          if (fatal) throw new Error('Incomplete UTF-16 sequence');
          result.push(0xFFFD);
        }
        return codePointsToString(result);
      }

      var codeUnit = (this.buffer << 8) | bytes[i++];
      this.buffer = null;
      this.processCodeUnit(codeUnit, result, fatal);
    }

    while (i < bytes.length - 1) {
      var codeUnit = (bytes[i] << 8) | bytes[i + 1];
      i += 2;
      this.processCodeUnit(codeUnit, result, fatal);
    }

    // Handle trailing byte
    if (i < bytes.length) {
      if (stream) {
        this.buffer = bytes[i];
      } else {
        if (fatal) throw new Error('Incomplete UTF-16 sequence');
        result.push(0xFFFD);
      }
    }

    return codePointsToString(result);
  };

  // Latin-1 Decoder
  function Latin1Decoder() {}

  Latin1Decoder.prototype.decode = function(bytes, stream, fatal) {
    var result = [];
    for (var i = 0; i < bytes.length; i++) {
      result.push(bytes[i]);
    }
    return stringFromCharCode(result);
  };

  // ASCII Decoder
  function ASCIIDecoder() {}

  ASCIIDecoder.prototype.decode = function(bytes, stream, fatal) {
    var result = [];
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] > 0x7F) {
        if (fatal) throw new Error('Invalid ASCII character');
        result.push(0xFFFD);
      } else {
        result.push(bytes[i]);
      }
    }
    return stringFromCharCode(result);
  };

  // Export polyfills only if native versions don't exist
  if (!nativeTextEncoder) {
    self.TextEncoder = TextEncoder;
  }

  if (!nativeTextDecoder) {
    self.TextDecoder = TextDecoder;
  }

  // Export for use in other modules
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
      TextEncoder: TextEncoder,
      TextDecoder: TextDecoder
    };
  }

  // Utility function to check if polyfill is active
  self.textEncodingPolyfill = {
    isPolyfilled: !nativeTextEncoder || !nativeTextDecoder,
    version: '1.0.0',
    supportedEncodings: ['utf-8', 'utf-16le', 'utf-16be', 'latin1', 'ascii']
  };

})(typeof self !== 'undefined' ? self : this);
