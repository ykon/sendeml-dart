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
    return Uint8List.fromList(utf8.encode(s));
  }

  group('indexToOptional', () {
    final f = (n) => indexToOptional(n);

    test('present', () {
      expect(f(0).isPresent, isTrue);
      expect(f(1).isPresent, isTrue);
    });

    test('empty', () {
      expect(f(-1).isEmpty, isTrue);
      expect(f(-2).isEmpty, isTrue);
    });
  });

  group('findCr', () {
    final f = (l, n) => findCr(l, n);
    final cr6 = uint8([0, 1, 2, 3, 4, 5, cr, 7, 8, 9]);

    test('present', () {
      final optOk = f(cr6, 0);
      expect(optOk.isPresent, isTrue);
      expect(optOk.value, equals(6));
    });

    test('empty', () {
      expect(f(cr6, 7).isEmpty, isTrue);

      final noCr = uint8([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(f(noCr, 0).isEmpty, isTrue);
    });
  });

  group('findLf', () {
    final f = (l, n) => findLf(l, n);
    final lf6 = uint8([0, 1, 2, 3, 4, 5, lf, 7, 8, 9]);
    test('present', () {
      final optOk = f(lf6, 0);
      expect(optOk.isPresent, isTrue);
      expect(optOk.value, equals(6));
    });

    test('empty', () {
      expect(f(lf6, 7).isEmpty, isTrue);

      final noLf = uint8([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]); 
      expect(f(noLf, 0).isEmpty, isTrue);
    });
  });

  group('findAllLf', () {
    test('zero', () {
      final data = uint8([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]); // not 10
      final indices = findAllLf(data);
      expect(indices.length, equals(0));
    });

    test('three', () {
      final data = uint8([0, 1, cr, lf, 4, 5, cr, lf, 8, 9, cr, lf]);
      final indices = findAllLf(data);
      expect(indices.length, equals(3));
      expect(indices[0], equals(3));
      expect(indices[1], equals(7));
      expect(indices[2], equals(11));
    });
  });

  group('isEmptyLine', () {
    final f = (l, n) => isEmptyLine(l, n);

    test('ok', () {
      final ok1 = uint8([0, 1, 2, 3, 4, cr, lf, cr, lf, 9]);
      expect(f(ok1, 5), isTrue);
      final ok2 = uint8([0, 1, 2, 3, 4, cr, lf, cr, lf]);
      expect(f(ok2, 5), isTrue);
    });

    test('bad', () {
      final bad1 = uint8([0, 1, 2, 3, 4, cr, lf, cr, 8, 9]);
      expect(f(bad1, 5), isFalse);
      final bad2 = uint8([0, 1, 2, 3, 4, cr, lf, cr]);
      expect(f(bad2, 5), isFalse);
      final bad3 = uint8([0, 1, 2, 3, 4, 5, cr, lf, cr, lf]);
      expect(f(bad3, 5), isFalse);
    });
  });

  group('findEmptyLine', () {
    final f = (l) => findEmptyLine(l);

    test('ok', () {
      final ok1 = uint8([0, 1, 2, 3, 4, cr, lf, cr, lf, 9]);
      expect(f(ok1).value, equals(5));
      final ok2 = uint8([0, 1, 2, 3, 4, 5, cr, lf, cr, lf]);
      expect(f(ok2).value, equals(6));
    });

    test('bad', () {
      final bad1 = uint8([0, 1, 2, 3, 4, cr, lf, cr, 8, 9]);
      expect(f(bad1).isEmpty, isTrue);
      final bad2 = uint8([0, 1, 2, 3, 4, cr, lf, cr]);
      expect(f(bad2).isEmpty, isTrue);
    });
  });

  group('splitMail', () {
    final f = (l) => splitMail(l);

    test('ok', () {
      final ok = uint8([0, 1, 2, cr, lf, cr, lf, 7, 8, 9]);
      final okMail = f(ok).value;
      expect(okMail.item1.toList(), equals([0, 1, 2]));
      expect(okMail.item2.toList(), equals([7, 8, 9]));
    });

    test('bad', () {
      final bad = uint8([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final badMail = f(bad);
      expect(badMail.isEmpty, isTrue);
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

  final three_lines = uint8([0, 1, cr, lf, 4, 5, cr, lf, 8, 9]);

  group('getLines', () {
    test('three', () {
      final lines = getLines(three_lines);
      expect(lines[0], equals([0, 1, cr, lf]));
      expect(lines[1], equals([4, 5, cr, lf]));
      expect(lines[2], equals([8, 9]));
    });
  });

  group('concatLines', () {
    test('three', () {
      final lines = [
        uint8([0, 1, cr, lf]), uint8([4, 5, cr, lf]), uint8([8, 9])
      ];
      expect(concatLines(lines), equals(three_lines));
    });
  });

  group('matchHeader', () {
    final f = (s1, s2) => matchHeader(strUint8(s1), strUint8(s2));

    test('true', () {
      expect(f('Test:', 'Test:'), isTrue);
      expect(f('Test:   ', 'Test:'), isTrue);
      expect(f('Test: xxx', 'Test:'), isTrue);
    });

    test('false', () {
      expect(f('', 'Test:'), isFalse);
      expect(f('T', 'Test:'), isFalse);
      expect(f('Test', 'Test:'), isFalse);
      expect(f('X-Test:', 'Test:'), isFalse);
    });

    test('exception', () {
      expect(() => f('Test:', ''), throwsArgumentError);
    });
  });

  group('isDateLine', () {
    final f = (s) => isDateLine(strUint8(s));

    test('true', () {
      expect(f('Date: xxx'), isTrue);
      expect(f('Date:xxx'), isTrue);
      expect(f('Date:'), isTrue);
      expect(f('Date:   '), isTrue);
    });

    test('false', () {
      expect(f(''), false);
      expect(f('Date'), false);
      expect(f('xxx: Date'), false);
      expect(f('X-Date: xxx'), false);
    });
  });

  group('isMsgIdLine', () {
    final f = (s) => isMsgIdLine(strUint8(s));

    test('true', () {
      expect(f('Message-ID: xxx'), isTrue);
      expect(f('Message-ID:xxx'), isTrue);
      expect(f('Message-ID:'), isTrue);
      expect(f('Message-ID:   '), isTrue);
    });

    test('false', () {
      expect(f(''), isFalse);
      expect(f('Message-ID'), isFalse);
      expect(f('xxx: Message-ID'), isFalse);
      expect(f('X-Message-ID: xxx'), isFalse);
    });
  });

  group('makeNowDateLine', () {
    test('line', () {
      // ToDo
    });
  });

  group('makeRandomMsgIdLine', () {
    test('line', () {
      final line = makeRandomMsgIdLine();
      expect(line.startsWith('Message-ID:'), isTrue);
      expect(line.endsWith(crlf), isTrue);
      expect(line.length, equals(76));
    });
  });

  group('isWsp', () {
    final f = (n) => isWsp(n);
    final code = (s) => s.codeUnitAt(0);

    test('true', () {
      expect(f(code(' ')), isTrue);
      expect(f(code('\t')), isTrue);
    });

    test('false', () {
      expect(f(code('\0')), isFalse);
      expect(f(code('a')), isFalse);
      expect(f(code('b')), isFalse);
    });
  });

  group('isFoldedLine', () {
    final f = (List<String> l) =>
      isFoldedLine(uint8(l.map((s) => s.codeUnitAt(0)).toList()));

    test('true', () {
      expect(f([' ', 'a', 'b']), isTrue);
      expect(f(['\t', 'a', 'b']), isTrue);
    });

    test('false', () {
      expect(f(['\0', 'a', 'b']), isFalse);
      expect(f(['a', 'a', ' ']), isFalse);
      expect(f(['b', 'a', '\t']), isFalse);
    });
  });

  group('replaceDateLine', () {
    test('0', () {
      // ToDo
    });
  });

  test('replaceMsgIdLine', () {
    // ToDo
  });

  test('replaceHeader', () {
    // ToDo
  });

  test('replaceMail', () {
    // ToDo
  });
}
