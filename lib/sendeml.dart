/**
 * Copyright (c) Yuki Ono.
 * Licensed under the MIT License.
 */

import 'dart:convert';
//import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:optional/optional.dart';
import 'package:tuple/tuple.dart';

final cr = '\r'.codeUnitAt(0);
final lf = '\n'.codeUnitAt(0);
final space = ' '.codeUnitAt(0);
final htab = '\t'.codeUnitAt(0);
const crlf = '\r\n';

final dateBytes = Uint8List.fromList(utf8.encode('Date:'));
final msgIdBytes = Uint8List.fromList(utf8.encode('Message-ID:'));

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

final equalsList = const ListEquality().equals;

bool isEmptyLine(Uint8List bytes, int idx) {
  return (bytes.length < (idx + 4))
      ? false
      : equalsList(bytes.sublist(idx, idx + 4), emptyLine);
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

bool matchHeader(Uint8List line, Uint8List header) {
  if (header.isEmpty) {
    throw ArgumentError('header is empty');
  }

  return (line.length < header.length) ? false
    : equalsList(line.sublist(0, header.length), header);
}

bool isDateLine(Uint8List line) {
  return matchHeader(line, dateBytes);
}

bool isMsgIdLine(Uint8List line) {
  return matchHeader(line, msgIdBytes);
}

String makeTimeZoneOffset(int min) {
  final first = (min.abs() ~/ 60).toString().padLeft(2, '0');
  final last = (min.abs() % 60).toString().padLeft(2, '0');
  return (min < 0 ? '-' : '+') + first + last;
}

String makeNowDateLine() {
  final now = DateTime.now();
  final date = DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').format(now);
  final zone = makeTimeZoneOffset(now.timeZoneOffset.inMinutes);

  return 'Date: $date $zone$crlf';
}

String makeRandomMsgIdLine() {
  const s = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const len = 62;
  final r = Random();
  final randStr = List.generate(len, (_) => s[r.nextInt(s.length)]).join();

  return 'Message-ID: $randStr$crlf';
}

typedef MatchLine = bool Function(Uint8List);
typedef MakeLine = String Function();

bool isWsp(int b) {
  return b == space || b == htab;
}

bool isFoldedLine(Uint8List bytes) {
  return bytes.isNotEmpty ? isWsp(bytes.first) : false;
}

List<Uint8List> replaceLine(List<Uint8List> lines, MatchLine matchLine, MakeLine makeLine) {
  final idx = lines.indexWhere(matchLine);
  if (idx == -1) {
    return lines;
  }

  final p1 = lines.sublist(0, idx);
  final p2 = [Uint8List.fromList(utf8.encode(makeLine()))];
  final p3 = lines.skip(idx + 1).skipWhile(isFoldedLine).toList();

  return p1 + p2 + p3;
}

List<Uint8List> replaceDateLine(List<Uint8List> lines) {
  return replaceLine(lines, isDateLine, makeNowDateLine);
}

List<Uint8List> replaceMsgIdLine(List<Uint8List> lines) {
  return replaceLine(lines, isMsgIdLine, makeRandomMsgIdLine);
}

Uint8List replaceHeader(Uint8List header, bool updateDate, bool updateMsgId) {
  final lines = getLines(header);

  final d = updateDate;
  final m = updateMsgId;
  return concatLines(
    (d && m) ? replaceMsgIdLine(replaceDateLine(lines))
    : (d && !m) ? replaceDateLine(lines)
    : (!d && m) ? replaceMsgIdLine(lines)
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
  //final data = File('simple.eml').readAsBytesSync();
  //print(data);

  //final decoded = utf8.decode(data);
  //print(decoded);

  //print(String.fromCharCodes(data));

  /*
  final res = splitMail(data);
  res.ifPresent((t) {
    print(t);
  });
  */

  //print(makeRandomMsgIdLine());
  //print(makeNowDateLine());

  print(makeTimeZoneOffset(0));
}
