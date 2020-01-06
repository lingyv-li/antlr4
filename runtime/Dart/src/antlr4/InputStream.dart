//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

import 'dart:math';

import './Token.dart';
// Vacuum all input from a string and then treat it like a buffer.

_loadString(stream) {
  stream._index = 0;
  stream.data = [];
  if (stream.decodeToUnicodeCodePoints) {
    for (var i = 0; i < stream.strdata.length;) {
      var codePoint = stream.strdata.codePointAt(i);
      stream.data.push(codePoint);
      i += codePoint <= 0xFFFF ? 1 : 2;
    }
  } else {
    for (var i = 0; i < stream.strdata.length; i++) {
      var codeUnit = stream.strdata.charCodeAt(i);
      stream.data.push(codeUnit);
    }
  }
  stream._size = stream.data.length;
}

// If decodeToUnicodeCodePoints is true, the input is treated
// as a series of Unicode code points.
//
// Otherwise, the input is treated as a series of 16-bit UTF-16 code
// units.
class InputStream {
  var name = "<empty>";
  var strdata;
  int _index;
  int _size;
  bool decodeToUnicodeCodePoints;
  InputStream(data, {this.decodeToUnicodeCodePoints = false}) {
    this.strdata = data;
    _loadString(this);
  }

  get index {
    return this._index;
  }

  get size {
    return this._size;
  }

// Reset the stream so that it's in the same state it was
// when the object was created *except* the data array is not
// touched.
//
  reset() {
    this._index = 0;
  }

  consume() {
    if (this._index >= this._size) {
      // assert this.LA(1) == Token.EOF
      throw ("cannot consume EOF");
    }
    this._index += 1;
  }

  LA(offset) {
    if (offset == 0) {
      return 0; // undefined
    }
    if (offset < 0) {
      offset += 1; // e.g., translate LA(-1) to use offset=0
    }
    var pos = this._index + offset - 1;
    if (pos < 0 || pos >= this._size) {
      // invalid
      return Token.EOF;
    }
    return this.data[pos];
  }

  LT(offset) {
    return this.LA(offset);
  }

// mark/release do nothing; we have entire buffer
  mark() {
    return -1;
  }

  release(marker) {}

// consume() ahead until p==_index; can't just set p=_index as we must
// update line and column. If we seek backwards, just set p
//
  seek(_index) {
    if (_index <= this._index) {
      this._index = _index; // just jump; don't update stream state (line,
      // ...)
      return;
    }
    // seek forward
    this._index = min(_index, this._size);
  }

  getText(start, stop) {
    if (stop >= this._size) {
      stop = this._size - 1;
    }
    if (start >= this._size) {
      return "";
    } else {
      if (this.decodeToUnicodeCodePoints) {
        var result = "";
        for (var i = start; i <= stop; i++) {
          result += String.fromCharCode(this.data[i]);
        }
        return result;
      } else {
        return this.strdata.slice(start, stop + 1);
      }
    }
  }

  toString() {
    return this.strdata;
  }
}
