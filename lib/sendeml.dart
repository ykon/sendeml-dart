/**
 * Copyright (c) Yuki Ono.
 * Licensed under the MIT License.
 */

import 'dart:convert';
import 'dart:io';
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
  if (bytes.length < (idx + 4)) return false;

  return equalsList(bytes.sublist(idx, idx + 4), emptyLine);
}

Optional<int> findEmptyLine(Uint8List bytes) {
  var offset = 0;

  while (true) {
    final idx = findCr(bytes, offset);
    if (idx.isEmpty || isEmptyLine(bytes, idx.value)) return idx;

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
    if (idx.isEmpty) return indices;

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
  if (header.isEmpty) throw ArgumentError('header is empty');
  if (line.length < header.length) return false;

  return equalsList(line.sublist(0, header.length), header);
}

bool isDateLine(Uint8List line) {
  return matchHeader(line, dateBytes);
}

bool isMsgIdLine(Uint8List line) {
  return matchHeader(line, msgIdBytes);
}

String padZero2(int n) {
  if (n < 0 || n > 99) throw ArgumentError('invalid number: $n');

  return n.toString().padLeft(2, '0');
}

String makeTimeZoneOffset(int min) {
  if (min < -720 || min > 840) throw ArgumentError('invalid number: $min');

  final first = padZero2(min.abs() ~/ 60);
  final last = padZero2(min.abs() % 60);
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

  return 'Message-ID: <$randStr>$crlf';
}

typedef MatchLine = bool Function(Uint8List);
typedef MakeLine = String Function();

bool isWsp(int b) {
  return b == space || b == htab;
}

bool isFoldedLine(Uint8List bytes) {
  return bytes.isNotEmpty ? isWsp(bytes.first) : false;
}

List<Uint8List> replaceLine(
    List<Uint8List> lines, MatchLine matchLine, MakeLine makeLine) {
  final idx = lines.indexWhere(matchLine);
  if (idx == -1) return lines;

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
  List<Uint8List> replace() {
    final lines = getLines(header);
    final d = updateDate;
    final m = updateMsgId;

    if (d && m) return replaceMsgIdLine(replaceDateLine(lines));
    if (d && !m) return replaceDateLine(lines);
    if (!d && m) return replaceMsgIdLine(lines);

    return lines;
  }

  return concatLines(replace());
}

Uint8List combineMail(Uint8List header, Uint8List body) {
  return Uint8List.fromList(header + emptyLine + body);
}

Optional<Uint8List> replaceMail(
    Uint8List bytes, bool updateDate, bool updateMsgId) {
  if (!updateDate && !updateMsgId) return Optional.of(bytes);

  return splitMail(bytes).map((mail) {
    final header = mail.item1;
    final body = mail.item2;
    return combineMail(replaceHeader(header, updateDate, updateMsgId), body);
  });
}

String makeJsonSample() {
  return '''{
    "smtpHost": "172.16.3.151",
    "smtpPort": 25,
    "fromAddress": "a001@ah62.example.jp",
    "toAddresses": [
        "a001@ah62.example.jp",
        "a002@ah62.example.jp",
        "a003@ah62.example.jp"
    ],
    "emlFiles": [
        "test1.eml",
        "test2.eml",
        "test3.eml"
    ],
    "updateDate": true,
    "updateMessageId": true,
    "useParallel": false
}''';
}

dynamic getSettingsFromText(String text) {
  return json.decode(text);
}

dynamic getSettings(String jsonFile) {
  return getSettingsFromText(new File(jsonFile).readAsStringSync());
}

void checkJsonValue(dynamic json, String key, String type) {
  if (!json.containsKey(key)) return;

  if (json[key].runtimeType.toString() != type) {
    throw FormatException('invalid type: $key: ${json[key]}');
  }
}

void checkJsonArrayValue(dynamic json, String key, String type) {
  if (!json.containsKey(key)) return;

  final array = json[key];
  if (array is! List) {
    throw FormatException('invalid type (array): $key: ${json[key]}');
  }

  final elm = array.firstWhere((v) => v.runtimeType.toString() != type,
      orElse: () => null);
  if (elm != null) {
    throw FormatException('invalid type (element): $key: $elm');
  }
}

void checkRequiredKeys(dynamic json) {
  const names = [
    'smtpHost',
    'smtpPort',
    'fromAddress',
    'toAddresses',
    'emlFiles'
  ];

  final key = names.firstWhere((k) => !json.containsKey(k), orElse: () => null);
  if (key != null) throw FormatException('key not found: $key');
}

void checkSettings(dynamic json) {
  checkRequiredKeys(json);

  checkJsonValue(json, 'smtpHost', 'String');
  checkJsonValue(json, 'smtpPort', 'int');
  checkJsonValue(json, 'fromAddress', 'String');
  checkJsonArrayValue(json, 'toAddresses', 'String');
  checkJsonArrayValue(json, 'emlFiles', 'String');
  checkJsonValue(json, 'updateDate', 'bool');
  checkJsonValue(json, 'updateMessageId', 'bool');
  checkJsonValue(json, 'useParallel', 'bool');
}

class Settings {
  final String smtpHost;
  final int smtpPort;
  final String fromAddress;
  final List<String> toAddresses;
  final List<String> emlFiles;
  final bool updateDate;
  final bool updateMessageId;
  final bool useParallel;

  Settings(this.smtpHost, this.smtpPort, this.fromAddress, this.toAddresses,
      this.emlFiles, this.updateDate, this.updateMessageId, this.useParallel);
}

Settings mapSettings(dynamic json) {
  return Settings(
      json['smtpHost'],
      json['smtpPort'],
      json['fromAddress'],
      json['toAddresses'].cast<String>(),
      json['emlFiles'].cast<String>(),
      json['updateDate'] ?? true,
      json['updateMessageId'] ?? true,
      json['useParallel'] ?? false);
}

final lastReplyRegex = RegExp(r'^\d{3} .+');

bool isLastReply(String line) {
  return lastReplyRegex.hasMatch(line);
}

bool isPositiveReply(String line) {
  final first = line.isNotEmpty ? line[0] : '';
  return first == '2' || first == '3';
}

String replaceCrLfDot(String cmd) {
  return cmd == '$crlf.' ? '<CRLF>.' : cmd;
}

typedef SendCmd = Future<void> Function(String);

Future<void> sendHello(SendCmd send) async {
  await send('EHLO localhost');
}

Future<void> sendQuit(SendCmd send) async {
  await send('QUIT');
}

Future<void> sendRset(SendCmd send) async {
  await send('RSET');
}

Future<void> sendData(SendCmd send) async {
  await send('DATA');
}

Future<void> sendFrom(SendCmd send, String fromAddr) async {
  await send('MAIL FROM: <$fromAddr>');
}

Future<void> sendRcptTo(SendCmd send, List<String> toAddrs) async {
  for (final addr in toAddrs) await send('RCPT TO: <$addr>');
}

Future<void> sendCrLfDot(SendCmd send) async {
  await send('$crlf.');
}

String makeIdPrefix(int id) {
  if (id < 0) throw ArgumentError('invalid number: $id');

  return (id > 0) ? 'id: $id, ' : '';
}

enum SendState { begin, from, rcptTo, data, mail, end }

SendState nextSendState(SendState state) {
  if (state == SendState.end) return state;
  if (state == SendState.mail) return SendState.begin;

  return SendState.values[state.index + 1];
}
