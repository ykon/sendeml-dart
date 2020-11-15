/**
 * Copyright (c) Yuki Ono.
 * Licensed under the MIT License.
 */

import 'dart:io';
//import 'dart:convert';
import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'package:optional/optional.dart';
import 'package:collection/collection.dart';

final cr = '\r'.codeUnitAt(0);
final lf = '\n'.codeUnitAt(0);

Optional<int> indexToOptional(int idx) {
  return idx > -1 ? Optional.of(idx) : Optional.empty();
}

Optional<int> findCr(Uint8List bytes, int offset) {
  final idx = bytes.indexOf(cr, offset);
  return indexToOptional(idx);
}

Optional<int> findLf(Uint8List bytes, int offset) {
  final idx = bytes.indexOf(lf, offset);
  return indexToOptional(idx);
}

final emptyLine = Uint8List.fromList([cr, lf, cr, lf]);

bool isEmptyLine(Uint8List bytes, int idx) {
  return (bytes.length < (idx + 4))
      ? false
      : ListEquality().equals(bytes.sublist(idx, idx + 4), emptyLine);
}

Optional<int> findEmptyLine(Uint8List bytes) {
  var offset = 0;

  while (true) {
    final idx = findCr(bytes, offset);
    if (idx.isEmpty || isEmptyLine(bytes, idx.value)) {
      return idx;
    }

    offset = idx.value + 1;
  }
}

Optional<Tuple2<Uint8List, Uint8List>> splitMail(Uint8List bytes) {
  return findEmptyLine(bytes).map((idx) => Tuple2<Uint8List, Uint8List>(
      bytes.sublist(0, idx), bytes.sublist(idx + emptyLine.length)));
}

List<int> findAllLf(Uint8List bytes) {
  final indices = <int>[];
  var offset = 0;

  while (true) {
    final idx = findLf(bytes, offset);
    if (idx.isEmpty) {
      return indices;
    }

    indices.add(idx.value);
    offset = idx.value + 1;
  }
}

List<Uint8List> getLines(Uint8List bytes) {
  var offset = 0;
  final indices = findAllLf(bytes);
  indices.add(bytes.length - 1);

  return indices.map((idx) {
    final line = bytes.sublist(offset, idx + 1);
    offset = idx + 1;
    return line;
  }).toList();
}

Uint8List concatLines(List<Uint8List> lines) {
  return Uint8List.fromList(lines.expand((x) => x).toList());
}

List<Uint8List> replaceDateLine(List<Uint8List> lines) {
  // ToDo
  return [];
}

List<Uint8List> replaceMsgIdLine(List<Uint8List> lines) {
  // ToDo
  return [];
}

Uint8List replaceHeader(Uint8List header, bool updateDate, bool updateMsgId) {
  final lines = getLines(header);

  return concatLines(
    updateDate && updateMsgId ? replaceMsgIdLine(replaceDateLine(lines))
    : updateDate && !updateMsgId ? replaceDateLine(lines)
    : !updateDate && updateMsgId ? replaceMsgIdLine(lines)
    : lines
  );
}

Uint8List combineMail(Uint8List header, Uint8List body) {
  return Uint8List.fromList(header + emptyLine + body);
}

Optional<Uint8List> replaceMail(Uint8List bytes, bool updateDate, bool updateMsgId) {
  if (!updateDate && !updateMsgId) {
    return Optional.of(bytes);
  }

  return splitMail(bytes).map((mail) {
    final header = mail.item1;
    final body = mail.item2;
    return combineMail(replaceHeader(header, updateDate, updateMsgId), body);
  });
}

void main() {
  final data = new File('simple.eml').readAsBytesSync();
  //print(data);

  //final decoded = utf8.decode(data);
  //print(decoded);

  //print(String.fromCharCodes(data));

  final res = splitMail(data);
  res.ifPresent((t) {
    print(t);
  });
}
