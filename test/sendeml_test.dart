/**
 * Copyright (c) Yuki Ono.
 * Licensed under the MIT License.
 */

import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:sendeml/sendeml.dart';
//import 'package:optional/optional.dart';

void main() {
  Uint8List uint8(List<int> list) {
    return Uint8List.fromList(list);
  }

  Uint8List strUint8(String s) {
    return uint8(utf8.encode(s));
  }

  void expectTrue(bool actual) {
    expect(actual, isTrue);
  }

  void expectFalse(bool actual) {
    expect(actual, isFalse);
  }

  group('indexToOptional', () {
    final f = indexToOptional;

    test('present', () {
      expectTrue(f(0).isPresent);
      expectTrue(f(1).isPresent);
    });

    test('empty', () {
      expectTrue(f(-1).isEmpty);
      expectTrue(f(-2).isEmpty);
    });
  });

  group('findCr', () {
    final f = (l, n) => findCr(uint8(l), n);
    final cr6 = [0, 1, 2, 3, 4, 5, cr, 7, 8, 9];

    test('present', () {
      final optOk = f(cr6, 0);
      expectTrue(optOk.isPresent);
      expect(optOk.value, equals(6));
    });

    test('empty', () {
      expectTrue(f(cr6, 7).isEmpty);

      final noCr = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      expectTrue(f(noCr, 0).isEmpty);
    });
  });

  group('findLf', () {
    final f = (l, n) => findLf(uint8(l), n);
    final lf6 = [0, 1, 2, 3, 4, 5, lf, 7, 8, 9];
    test('present', () {
      final optOk = f(lf6, 0);
      expectTrue(optOk.isPresent);
      expect(optOk.value, equals(6));
    });

    test('empty', () {
      expectTrue(f(lf6, 7).isEmpty);

      final noLf = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      expectTrue(f(noLf, 0).isEmpty);
    });
  });

  final threeLines = uint8([0, 1, cr, lf, 4, 5, cr, lf, 8, 9]);

  group('findAllLf', () {
    final f = findAllLf;

    test('zero', () {
      final not10 = uint8([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]);
      final indices = f(not10);
      expect(indices.length, equals(0));
    });

    test('three', () {
      final indices = f(threeLines);
      expect(indices.length, equals(2));
      expect(indices[0], equals(3));
      expect(indices[1], equals(7));
    });
  });

  group('isEmptyLine', () {
    final f = (l, n) => isEmptyLine(uint8(l), n);

    test('ok', () {
      expectTrue(f([0, 1, 2, 3, 4, cr, lf, cr, lf, 9], 5));
      expectTrue(f([0, 1, 2, 3, 4, cr, lf, cr, lf], 5));
    });

    test('bad', () {
      expectFalse(f([0, 1, 2, 3, 4, cr, lf, cr, 8, 9], 5));
      expectFalse(f([0, 1, 2, 3, 4, cr, lf, cr], 5));
      expectFalse(f([0, 1, 2, 3, 4, 5, cr, lf, cr, lf], 5));
    });
  });

  group('findEmptyLine', () {
    final f = (l) => findEmptyLine(uint8(l));

    test('ok', () {
      expect(f([0, 1, 2, 3, 4, cr, lf, cr, lf, 9]).value, equals(5));
      expect(f([0, 1, 2, 3, 4, 5, cr, lf, cr, lf]).value, equals(6));
    });

    test('bad', () {
      expectTrue(f([0, 1, 2, 3, 4, cr, lf, cr, 8, 9]).isEmpty);
      expectTrue(f([0, 1, 2, 3, 4, cr, lf, cr]).isEmpty);
    });
  });

  group('splitMail', () {
    final f = (l) => splitMail(uint8(l));

    test('ok', () {
      final okMail = f([0, 1, 2, cr, lf, cr, lf, 7, 8, 9]).value;
      expect(okMail.item1.toList(), equals([0, 1, 2]));
      expect(okMail.item2.toList(), equals([7, 8, 9]));
    });

    test('bad', () {
      final badMail = f([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expectTrue(badMail.isEmpty);
    });
  });

  group('combineMail', () {
    test('3 + 4 + 3', () {
      final header = uint8([0, 1, 2]);
      final body = uint8([7, 8, 9]);
      final mail = combineMail(header, body);
      expect(mail.toList(), equals([0, 1, 2, cr, lf, cr, lf, 7, 8, 9]));
    });
  });

  group('getLines', () {
    test('three', () {
      final lines = getLines(threeLines);
      expect(lines[0], equals([0, 1, cr, lf]));
      expect(lines[1], equals([4, 5, cr, lf]));
      expect(lines[2], equals([8, 9]));
    });
  });

  group('concatLines', () {
    test('three', () {
      final lines = [
        [0, 1, cr, lf],
        [4, 5, cr, lf],
        [8, 9]
      ].map(uint8).toList();
      expect(concatLines(lines), equals(threeLines));
    });
  });

  group('matchHeader', () {
    final f = (s1, s2) => matchHeader(strUint8(s1), strUint8(s2));

    test('true', () {
      expectTrue(f('Test:', 'Test:'));
      expectTrue(f('Test:   ', 'Test:'));
      expectTrue(f('Test: xxx', 'Test:'));
    });

    test('false', () {
      expectFalse(f('', 'Test:'));
      expectFalse(f('T', 'Test:'));
      expectFalse(f('Test', 'Test:'));
      expectFalse(f('X-Test:', 'Test:'));
    });

    test('error', () {
      expect(() => f('Test:', ''), throwsArgumentError);
    });
  });

  group('isDateLine', () {
    final f = (s) => isDateLine(strUint8(s));

    test('true', () {
      expectTrue(f('Date: xxx'));
      expectTrue(f('Date:xxx'));
      expectTrue(f('Date:'));
      expectTrue(f('Date:   '));
    });

    test('false', () {
      expectFalse(f(''));
      expectFalse(f('Date'));
      expectFalse(f('xxx: Date'));
      expectFalse(f('X-Date: xxx'));
    });
  });

  group('isMsgIdLine', () {
    final f = (s) => isMsgIdLine(strUint8(s));

    test('true', () {
      expectTrue(f('Message-ID: xxx'));
      expectTrue(f('Message-ID:xxx'));
      expectTrue(f('Message-ID:'));
      expectTrue(f('Message-ID:   '));
    });

    test('false', () {
      expectFalse(f(''));
      expectFalse(f('Message-ID'));
      expectFalse(f('xxx: Message-ID'));
      expectFalse(f('X-Message-ID: xxx'));
    });
  });

  group('padZero2', () {
    final f = padZero2;

    test('ok', () {
      expect(f(0), equals('00'));
      expect(f(1), equals('01'));
      expect(f(10), equals('10'));
      expect(f(99), equals('99'));
    });

    test('error', () {
      expect(() => f(-1), throwsArgumentError);
      expect(() => f(100), throwsArgumentError);
    });
  });

  group('makeTimeZoneOffset', () {
    final f = makeTimeZoneOffset;
    test('positive', () {
      expect(f(840), equals('+1400'));
      expect(f(540), equals('+0900'));
      expect(f(480), equals('+0800'));
      expect(f(420), equals('+0700'));
      expect(f(0), equals('+0000'));
    });

    test('negative', () {
      expect(f(-720), equals('-1200'));
      expect(f(-540), equals('-0900'));
      expect(f(-480), equals('-0800'));
      expect(f(-420), equals('-0700'));
      expect(f(-1), equals('-0001'));
    });

    test('error', () {
      expect(() => f(841), throwsArgumentError);
      expect(() => f(-721), throwsArgumentError);
    });
  });

  group('makeNowDateLine', () {
    test('line', () {
      final line = makeNowDateLine();
      expectTrue(line.startsWith('Date:'));
      expectTrue(line.endsWith(crlf));
      expectTrue(line.length <= 78);
    });
  });

  group('makeRandomMsgIdLine', () {
    test('line', () {
      final line = makeRandomMsgIdLine();
      expectTrue(line.startsWith('Message-ID:'));
      expectTrue(line.endsWith(crlf));
      expect(line.length, equals(78));
    });
  });

  group('isWsp', () {
    final f = isWsp;
    final code = (s) => s.codeUnitAt(0);

    test('true', () {
      expectTrue(f(code(' ')));
      expectTrue(f(code('\t')));
    });

    test('false', () {
      expectFalse(f(code('\0')));
      expectFalse(f(code('a')));
      expectFalse(f(code('b')));
    });
  });

  group('isFoldedLine', () {
    final f = (List<String> l) =>
        isFoldedLine(uint8(l.map((s) => s.codeUnitAt(0)).toList()));

    test('true', () {
      expectTrue(f([' ', 'a', 'b']));
      expectTrue(f(['\t', 'a', 'b']));
    });

    test('false', () {
      expectFalse(f(['\0', 'a', 'b']));
      expectFalse(f(['a', 'a', ' ']));
      expectFalse(f(['b', 'a', '\t']));
    });
  });

  String toCrLf(String lfStr) {
    return lfStr.replaceAll('\n', crlf);
  }

  String makeSimpleMailText() {
    final text = '''From: a001 <a001@ah62.example.jp>
Subject: test
To: a002@ah62.example.jp
Message-ID: <b0e564a5-4f70-761a-e103-70119d1bcb32@ah62.example.jp>
Date: Sun, 26 Jul 2020 22:01:37 +0900
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:78.0) Gecko/20100101
 Thunderbird/78.0.1
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8; format=flowed
Content-Transfer-Encoding: 7bit
Content-Language: en-US

test''';
    return toCrLf(text);
  }

  String makeFoldedMailText() {
    const text = '''From: a001 <a001@ah62.example.jp>
Subject: test
To: a002@ah62.example.jp
Message-ID:
 <b0e564a5-4f70-761a-e103-70119d1bcb32@ah62.example.jp>
Date:
 Sun, 26 Jul 2020
 22:01:37 +0900
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:78.0) Gecko/20100101
 Thunderbird/78.0.1
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8; format=flowed
Content-Transfer-Encoding: 7bit
Content-Language: en-US

test''';
    return toCrLf(text);
  }

  Uint8List makeInvalidMail() {
    return strUint8(makeFoldedMailText().replaceFirst('\r\n\r\n', ''));
  }

  group('make*Text', () {
    test('simple', () {
      final text = makeSimpleMailText();
      expect('\r\n'.allMatches(text).length, equals(12));
    });

    test('folded', () {
      final text = makeFoldedMailText();
      expect('\r\n'.allMatches(text).length, equals(15));
    });
  });

  Uint8List makeSimpleMail() {
    return strUint8(makeSimpleMailText());
  }

  Uint8List makeFoldedMail() {
    return strUint8(makeFoldedMailText());
  }

  String getHeaderLine(Uint8List mail, String name) {
    final text = utf8.decode(mail);

    final re = RegExp(name + r':[\s\S]+?\r\n(?=([^ \t]|$))');
    return re.firstMatch(text).group(0);
  }

  String getDateLine(Uint8List mail) {
    return getHeaderLine(mail, 'Date');
  }

  String getMsgIdLine(Uint8List mail) {
    return getHeaderLine(mail, 'Message-ID');
  }

  group('replaceDateLine', () {
    test('folded', () {
      final mail = makeFoldedMail();
      final lines = getLines(mail);
      final newLines = replaceDateLine(lines);
      final newMail = concatLines(newLines);
      expectFalse(equalsList(mail, newMail));
      expectTrue(getDateLine(newMail) != getDateLine(mail));
      expectTrue(getMsgIdLine(newMail) == getMsgIdLine(mail));
    });
  });

  group('replaceMsgIdLine', () {
    test('folded', () {
      final mail = makeFoldedMail();
      final lines = getLines(mail);
      final newLines = replaceMsgIdLine(lines);
      final newMail = concatLines(newLines);
      expectFalse(equalsList(mail, newMail));
      expectTrue(getMsgIdLine(newMail) != getMsgIdLine(mail));
      expectTrue(getDateLine(newMail) == getDateLine(mail));
    });
  });

  group('replaceHeader', () {
    final f = replaceHeader;

    final mail = makeFoldedMail();
    final dateLine = getDateLine(mail);
    final msgIdLine = getMsgIdLine(mail);

    test('true, true', () {
      final replMail = f(mail, true, true);
      expectTrue(dateLine != getDateLine(replMail));
      expectTrue(msgIdLine != getMsgIdLine(replMail));
    });

    test('true, false', () {
      final replMail = f(mail, true, false);
      expectTrue(dateLine != getDateLine(replMail));
      expectTrue(msgIdLine == getMsgIdLine(replMail));
    });

    test('false, true', () {
      final replMail = f(mail, false, true);
      expectTrue(dateLine == getDateLine(replMail));
      expectTrue(msgIdLine != getMsgIdLine(replMail));
    });

    test('false, false', () {
      final replMail = f(mail, false, false);
      expectTrue(equalsList(replMail, mail));
    });
  });

  group('replaceMail', () {
    final f = replaceMail;

    test('replace', () {
      final mail = makeFoldedMail();
      final replMail = f(mail, true, true).value;
      expectFalse(equalsList(replMail, mail));
      final body = replMail.sublist(replMail.length - 4);
      expect(utf8.decode(body), equals('test'));
    });

    test('invalid', () {
      expectTrue(f(makeInvalidMail(), true, true).isEmpty);
    });
  });
}
