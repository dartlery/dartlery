import 'package:dartlery_shared/global.dart';
import 'package:logging/logging.dart';
import 'package:mime/mime.dart';
import "package:hex/hex.dart";

class MediaMimeResolver extends MimeTypeResolver {
  static final Logger _log = new Logger('MediaMimeResolver');

  MediaMimeResolver() : super() {
    //addMagicNumber(<int>[0x1A, 0x45, 0xDF, 0xA3, 0x93, 0x42, 0x82, 0x88,
    //              0x6D, 0x61, 0x74, 0x72, 0x6F, 0x73, 0x6B, 0x61], MimeTypes.mkv);

    addMagicNumber(<int>[0x1A, 0x45, 0xDF, 0xA3], MimeTypes.mkv);

    // M4V files, which are really just mp4 files
    addMagicNumber(
        <int>[0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x56],
        MimeTypes.mp4,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(
        <int>[0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34],
        MimeTypes.mp4,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(
        <int>[
          0x00,
          0x00,
          0x00,
          0x14,
          0x66,
          0x74,
          0x79,
          0x70,
          0x69,
          0x73,
          0x6F,
          0x6D
        ],
        MimeTypes.mp4,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(
        <int>[
          0x00,
          0x00,
          0x00,
          0x14,
          0x66,
          0x74,
          0x79,
          0x70,
          0x4D,
          0x53,
          0x4E,
          0x56
        ],
        MimeTypes.mp4,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    // XAVC files
    addMagicNumber(
        <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0x66,
          0x74,
          0x79,
          0x70,
          0x58,
          0x41,
          0x56,
          0x43
        ],
        MimeTypes.mp4,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(
        <int>[
          0x00,
          0x00,
          0x00,
          0x18,
          0x66,
          0x74,
          0x79,
          0x70,
          0x33,
          0x67,
          0x70,
          0x35
        ],
        MimeTypes.mp4,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(<int>[
      0x00,
      0x00,
      0x00,
      0x1C,
      0x66,
      0x74,
      0x79,
      0x70,
      0x4D,
      0x53,
      0x4E,
      0x56,
      0x01,
      0x29,
      0x00,
      0x46,
      0x4D,
      0x53,
      0x4E,
      0x56,
      0x6D,
      0x70,
      0x34,
      0x32
    ], MimeTypes.mp4);

    addMagicNumber(
        <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0x66,
          0x74,
          0x79,
          0x70,
          0x71,
          0x74,
          0x20,
          0x20
        ],
        MimeTypes.quicktime,
        mask: <int>[
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(<int>[0x43, 0x57, 0x53], MimeTypes.swf);
    addMagicNumber(<int>[0x46, 0x57, 0x53], MimeTypes.swf);
    addMagicNumber(<int>[0x46, 0x4C, 0x56, 0x01], MimeTypes.flv);

    addMagicNumber(
        <int>[
          0x52,
          0x49,
          0x46,
          0x46,
          0x00,
          0x00,
          0x00,
          0x00,
          0x41,
          0x56,
          0x49,
          0x20,
          0x4C,
          0x49,
          0x53,
          0x54
        ],
        MimeTypes.avi,
        mask: <int>[
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0x00,
          0x00,
          0x00,
          0x00,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF
        ]);

    addMagicNumber(<int>[
      0x30,
      0x26,
      0xB2,
      0x75,
      0x8E,
      0x66,
      0xCF,
      0x11,
      0xA6,
      0xD9,
      0x00,
      0xAA,
      0x00,
      0x62,
      0xCE,
      0x6C
    ], MimeTypes.asf);

    addMagicNumber(<int>[0x00, 0x00, 0x01, 0xB0], MimeTypes.mpeg,
        mask: <int>[0xFF, 0xFF, 0xFF, 0xF0]);
  }

  String getMimeType(List<int> data) {
    List<int> lookupBytes;
    if (data.length > magicNumbersMaxLength) {
      lookupBytes = data.sublist(0, magicNumbersMaxLength);
    } else {
      lookupBytes = data;
    }

    _log.info("Header bytes: ${HEX.encode(lookupBytes)}");

    return lookup("", headerBytes: lookupBytes);
  }
}
