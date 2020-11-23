/**
 * Copyright (c) Yuki Ono.
 * Licensed under the MIT License.
 */

import 'package:sendeml/sendeml.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const programVersion = '1.0';

void printUsage() {
  print('Usage: {self} json_file ...');
  print('...');

  print('json_file sample:');
  print(makeJsonSample());
}

void printVersion() {
  print('SendEML / Version $programVersion');
}

Stream<String> recvLine(Socket socket, {int id = 0}) async* {
  const lf = '\n';
  var buf = '';

  await for (final data in socket) {
    buf += utf8.decode(data);

    while (true) {
      final idx = buf.indexOf(lf);
      if (idx == -1) break;

      final line = buf.substring(0, idx);
      buf = buf.substring(idx + 1);

      print(makeIdPrefix(id) + 'recv: $line');

      if (isLastReply(line)) {
        if (isPositiveReply(line)) {
          yield line;
        } else {
          throw StateError(line);
        }
      }
    }
  }

  yield buf;
}

Future<void> sendLine(Socket socket, String cmd, {int id = 0}) async {
  print(makeIdPrefix(id) + 'send: ${replaceCrLfDot(cmd)}');

  await socket.add(utf8.encode(cmd + crlf));
  await socket.flush();
}

Future<void> sendMail(
    Socket socket, String file, bool updateDate, bool updateMsgId,
    {int id = 0}) async {
  print(makeIdPrefix(id) + 'send: $file');

  final mail = await File(file).readAsBytes();
  final replMail = replaceMail(mail, updateDate, updateMsgId);

  if (replMail.isEmpty) {
    print('error: Invalid mail: Disable updateDate, updateMessageId');
  }

  await socket.add(replMail.orElse(mail));
  await socket.flush();
}

SendCmd makeSendCmd(Socket socket, {int id = 0}) {
  return (String cmd) async {
    await sendLine(socket, cmd, id: id);
  };
}

Future<int> checkEmlFiles(Settings settings, int emlIdx) async {
  var idx = emlIdx;
  final emlFiles = settings.emlFiles;
  while (true) {
    if (idx >= emlFiles.length) return idx;

    final file = emlFiles[idx];
    if (await File(file).exists()) return idx;

    print('error: .eml file not found: $file');
    idx += 1;
  }
}

Future<void> sendMessages(Settings settings, List<String> emlFiles,
    {int id = 0}) async {
  await Socket.connect(settings.smtpHost, settings.smtpPort)
      .then((socket) async {
    var emlIdx = 0;
    var state = SendState.begin;
    final send = makeSendCmd(socket, id: id);
    var reset = false;

    Future<void> doBeginState() async {
      emlIdx = await checkEmlFiles(settings, emlIdx);
      if (emlIdx >= settings.emlFiles.length) {
        sendQuit(send);
        state = SendState.end;
      } else {
        await (reset ? sendRset : sendHello)(send);
      }
    }

    Future<void> doMailState() async {
      final file = settings.emlFiles[emlIdx++];
      await sendMail(
          socket, file, settings.updateDate, settings.updateMessageId,
          id: id);
      await sendCrLfDot(send);
      reset = true;
    }

    loop:
    await for (final _ in recvLine(socket, id: id)) {
      switch (state) {
        case SendState.begin:
          await doBeginState();
          break;
        case SendState.from:
          await sendFrom(send, settings.fromAddress);
          break;
        case SendState.rcptTo:
          await sendRcptTo(send, settings.toAddresses);
          break;
        case SendState.data:
          await sendData(send);
          break;
        case SendState.mail:
          await doMailState();
          break;
        case SendState.end:
          break loop;
        default:
          throw StateError('invalid state: ' + state.toString());
      }
      state = nextSendState(state);
    }
    await socket.close();
  });
}

Future<void> procJsonFile(String jsonFile) async {
  if (!await File(jsonFile).exists()) {
    print('error: JSON file not found: $jsonFile');
    return;
  }

  try {
    final json = getSettings(jsonFile);
    checkSettings(json);

    final settings = mapSettings(json);

    if (settings.useParallel && settings.emlFiles.length > 1) {
      var id = 1;
      for (final f in settings.emlFiles) {
        sendMessages(settings, [f], id: id++);
      }
    } else {
      await sendMessages(settings, settings.emlFiles);
    }
  } catch (e) {
    print('error: $e');
  }
}

void main(List<String> args) async {
  if (args.length == 0) {
    printUsage();
    return;
  }

  if (args[0] == '--version') {
    printVersion();
    return;
  }

  for (final jsonFile in args) {
    await procJsonFile(jsonFile);
  }
}
