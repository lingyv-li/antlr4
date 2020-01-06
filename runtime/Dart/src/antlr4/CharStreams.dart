//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//


// Utility functions to create InputStreams from various sources.
//
// All returned InputStreams support the full range of Unicode
// up to U+10FFFF (the default behavior of InputStream only supports
// code points up to U+FFFF).
import 'dart:convert';
import 'dart:io';

import 'InputStream.dart';

class CharStreams {
  // Creates an InputStream from a string.
  static fromString(str) {
    return new InputStream(str, decodeToUnicodeCodePoints:true);
  }

  // TODO implement this
  // Asynchronously creates an InputStream from a blob given the
  // encoding of the bytes in that blob (defaults to 'utf8' if
  // encoding is null).
  //
  // Invokes onLoad(result) on success, onError(error) on
  // failure.
  // fromBlob(blob, encoding, onLoad, onError) {

  //   File(fileName).openRead().transform(utf8.decoder)
  //   var reader = FileReader();
  //   reader.onload = function(e) {
  //     var is = new InputStream(e.target.result, decodeToUnicodeCodePoints:true);
  //     onLoad(is);
  //   };
  //   reader.onerror = onError;
  //   reader.readAsText(blob, encoding);
  // }

  // Creates an InputStream from a Buffer given the
  // encoding of the bytes in that buffer (defaults to 'utf8' if
  // encoding is null).
  fromBuffer(buffer, encoding) {
    return new InputStream(buffer.toString(encoding),decodeToUnicodeCodePoints: true);
  }

  static fromPath(path,  Converter<List<int>, String> encoding) {
    final data =File(path).openRead().transform(encoding);
    return new InputStream(data, decodeToUnicodeCodePoints:true);
  }
  // TODO fromPathSync
}
