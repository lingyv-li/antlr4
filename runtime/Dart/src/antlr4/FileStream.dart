//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

//
//  This is an InputStream that is loaded from a file all at once
//  when you construct the object.
//
import 'dart:convert';
import 'dart:io';
import 'InputStream.dart';

class FileStream extends InputStream {
  final fileName;
  FileStream(this.fileName, decodeToUnicodeCodePoints)
      : super(File(fileName).openRead().transform(utf8.decoder),
            decodeToUnicodeCodePoints: decodeToUnicodeCodePoints);
}
