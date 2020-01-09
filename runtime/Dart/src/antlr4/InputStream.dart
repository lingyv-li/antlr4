//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'Token.dart';
import 'CharStream.dart';
import 'IntStream.dart';
import 'IntervalSet.dart';

// Vacuum all input from a string and then treat it like a buffer.
class InputStream extends CharStream {
  var name = "<empty>";
  List<int> data;
  int _index;
  int _size;
  bool decodeToUnicodeCodePoints;

  InputStream(List<int> data) {
    this.data = data;
  }

  InputStream.fromString(String data) {
    this.data = data.codeUnits;
  }

  static Future<InputStream> fromStringStream(Stream<String> stream) async {
    final data = StringBuffer();
    await stream.listen((buf) {
      data.write(buf);
    }).asFuture();
    return InputStream.fromString(data.toString());
  }

  static Future<InputStream> fromStream(Stream<List<int>> stream,
      {Encoding encoding = utf8}) {
    final data = stream.transform(encoding.decoder);
    return fromStringStream(data);
  }

  static Future<InputStream> fromPath(String path, {Encoding encoding = utf8}) {
    return fromStream(File(path).openRead());
  }

  get index {
    return this._index;
  }

  get size {
    return this._size;
  }

  /// Reset the stream so that it's in the same state it was
  /// when the object was created *except* the data array is not
  /// touched.
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

  int LA(int offset) {
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

  /// mark/release do nothing; we have entire buffer
  int mark() {
    return -1;
  }

  release(int marker) {}

  /// consume() ahead until p==_index; can't just set p=_index as we must
  /// update line and column. If we seek backwards, just set p
  seek(int _index) {
    if (_index <= this._index) {
      this._index = _index; // just jump; don't update stream state (line,
      // ...)
      return;
    }
    // seek forward
    this._index = min(_index, this._size);
  }

  String getText(Interval interval) {
    final startIdx = min(interval.a, size);
    final len = min(interval.b - interval.a + 1, size - startIdx);
    return String.fromCharCodes(this.data, startIdx, startIdx + len);
  }

  toString() {
    return String.fromCharCodes(this.data);
  }

  @override
  String get sourceName {
    // TODO: implement getSourceName
    return IntStream.UNKNOWN_SOURCE_NAME;
  }
}
