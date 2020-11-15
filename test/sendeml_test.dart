/**
 * Copyright (c) Yuki Ono.
 * Licensed under the MIT License.
 */

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:sendeml/sendeml.dart';
//import 'package:optional/optional.dart';

void main() {
  test('indexToOptional', () {
    expect(indexToOptional(0).isPresent, isTrue);
    expect(indexToOptional(1).isPresent, isTrue);

    expect(indexToOptional(-1).isEmpty, isTrue);
    expect(indexToOptional(-2).isEmpty, isTrue);
  });

  test('findCr', () {
    final cr6 = Uint8List.fromList([0, 1, 2, 3, 4, 5, cr, 7, 8, 9]);
    final optOk = findCr(cr6, 0);
    expect(optOk.isPresent, isTrue);
    expect(optOk.value, equals(6));

    expect(findCr(cr6, 7).isEmpty, isTrue);

    final noCr = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(findCr(noCr, 0).isEmpty, isTrue);
  });

  test('findLf', () {
    final lf6 = Uint8List.fromList([0, 1, 2, 3, 4, 5, lf, 7, 8, 9]);
    final optOk = findLf(lf6, 0);
    expect(optOk.isPresent, isTrue);
    expect(optOk.value, equals(6));

    expect(findLf(lf6, 7).isEmpty, isTrue);

    final noLf = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]); 
    expect(findLf(noLf, 0).isEmpty, isTrue);
  });

  test('findAllLf', () {
    final data = Uint8List.fromList([0, 1, cr, lf, 4, 5, cr, lf, 8, 9]);
    final indices = findAllLf(data);
    expect(indices.length, equals(2));
    expect(indices[0], equals(3));
    expect(indices[1], equals(7));
  });

  test('isEmptyLine', () {
    final ok1 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr, lf, 9]);
    expect(isEmptyLine(ok1, 5), isTrue);
    final ok2 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr, lf]);
    expect(isEmptyLine(ok2, 5), isTrue);

    final bad1 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr, 8, 9]);
    expect(isEmptyLine(bad1, 5), isFalse);
    final bad2 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr]);
    expect(isEmptyLine(bad2, 5), isFalse);
    final bad3 = Uint8List.fromList([0, 1, 2, 3, 4, 5, cr, lf, cr, lf]);
    expect(isEmptyLine(bad3, 5), isFalse);
  });

  test('findEmptyLine', () {
    final ok1 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr, lf, 9]);
    expect(findEmptyLine(ok1).value, equals(5));
    final ok2 = Uint8List.fromList([0, 1, 2, 3, 4, 5, cr, lf, cr, lf]);
    expect(findEmptyLine(ok2).value, equals(6));

    final bad1 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr, 8, 9]);
    expect(findEmptyLine(bad1).isEmpty, isTrue);
    final bad2 = Uint8List.fromList([0, 1, 2, 3, 4, cr, lf, cr]);
    expect(findEmptyLine(bad2).isEmpty, isTrue);
  });

  test('splitMail', () {
    final ok = Uint8List.fromList([0, 1, 2, cr, lf, cr, lf, 7, 8, 9]);
    final okMail = splitMail(ok).value;
    expect(okMail.item1.toList(), equals([0, 1, 2]));
    expect(okMail.item2.toList(), equals([7, 8, 9]));

    final bad = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    final badMail = splitMail(bad);
    expect(badMail.isEmpty, isTrue);
  });

  test('combineMail', () {
    final header = Uint8List.fromList([0, 1, 2]);
    final body = Uint8List.fromList([7, 8, 9]);
    final mail = combineMail(header, body);
    expect(mail.toList(), equals([0, 1, 2, cr, lf, cr, lf, 7, 8, 9]));
  });

  test('getLines', () {
    final data = Uint8List.fromList([0, 1, cr, lf, 4, 5, cr, lf, 8, 9]);
    final lines = getLines(data);
    expect(lines[0], equals([0, 1, cr, lf]));
    expect(lines[1], equals([4, 5, cr, lf]));
    expect(lines[2], equals([8, 9]));
  });

  test('concatLines', () {
    final lines = [
      Uint8List.fromList([0, 1, cr, lf]),
      Uint8List.fromList([4, 5, cr, lf]),
      Uint8List.fromList([8, 9])
    ];
    expect(concatLines(lines), equals([0, 1, cr, lf, 4, 5, cr, lf, 8, 9]));
  });

  test('replaceDateLine', () {
    // ToDo
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
