## SendEML
A testing tool for sending raw eml files.
* SendEML-dart runs on Dart 2.10.4 or later.
  > [Dart - Get the Dart SDK](https://dart.dev/get-dart)  
  > [Dart - Dart SDK archive](https://dart.dev/tools/sdk/archive)

## Usage

### Run
```
cd sendeml-dart
pub get

Windows: dart .\bin\sendeml.dart <setting_file> ...
Others: dart ./bin/sendeml.dart <setting_file> ...
```

## Setting File (JSON format)
```
{
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
}
```

## Options

* updateDate (default: true)
  - Replace "Date:" line with the current date and time.

* updateMessageId (default: true)
  - Replace "Message-ID:" line with a new random string ID.

* useParallel (default: false)
  - Enable parallel processing for eml files.
