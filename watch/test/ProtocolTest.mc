import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Test;

(:test)
function encodeNextPrevious(logger as Logger) as Boolean {
    Test.assertEqual(Protocol.encodeNext(), [0x02]b);
    Test.assertEqual(Protocol.encodePrevious(), [0x03]b);
    return true;
}

(:test)
function encodeHelloLayout(logger as Logger) as Boolean {
    var id = [1, 2, 3, 4, 5, 6, 7, 8]b;
    var out = Protocol.encodeHello(id, "fenix 6");
    var expected = [0x01, 1, 2, 3, 4, 5, 6, 7, 8, 0x66, 0x65, 0x6E, 0x69, 0x78, 0x20, 0x36]b;
    Test.assertEqual(out, expected);
    Test.assert(out.size() <= 20);
    return true;
}

(:test)
function encodeHelloEmptyNameUsesGarmin(logger as Logger) as Boolean {
    var out = Protocol.encodeHello([1, 2, 3, 4, 5, 6, 7, 8]b, "");
    Test.assertEqual(out.size(), 9 + 6);
    Test.assertEqual(out.slice(9, null), [0x47, 0x61, 0x72, 0x6D, 0x69, 0x6E]b);
    return true;
}

(:test)
function encodeHelloTruncatesUtf8(logger as Logger) as Boolean {
    var id = [1, 2, 3, 4, 5, 6, 7, 8]b;
    var out = Protocol.encodeHello(id, "Фёдорович");
    Test.assert(out.size() <= 20);
    var tail = out.slice(9, null);
    // 11-byte limit lands mid-character (2-byte chars): must back off to 10 bytes.
    Test.assertEqual(tail.size(), 10);
    var s = StringUtil.convertEncodedString(tail, {
        :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
        :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
        :encoding => StringUtil.CHAR_ENCODING_UTF8
    });
    Test.assertEqual(s, "Фёдор");
    return true;
}

(:test)
function decodeMacInfoOk(logger as Logger) as Boolean {
    var data = [1, 2, 3, 4, 5, 6, 7, 8, 0x4D, 0x61, 0x63, 0x42, 0x6F, 0x6F, 0x6B]b;
    var info = Protocol.decodeMacInfo(data);
    Test.assert(info != null);
    Test.assertEqual(info[:id], [1, 2, 3, 4, 5, 6, 7, 8]b);
    Test.assertEqual(info[:name], "MacBook");
    return true;
}

(:test)
function decodeMacInfoShort(logger as Logger) as Boolean {
    Test.assert(Protocol.decodeMacInfo([1, 2, 3, 4, 5, 6, 7]b) == null);
    return true;
}

(:test)
function decodeMacInfoTooLong(logger as Logger) as Boolean {
    Test.assert(Protocol.decodeMacInfo(new [23]b) == null);
    Test.assert(Protocol.decodeMacInfo(new [22]b) != null);
    return true;
}

(:test)
function decodeMacInfoNoName(logger as Logger) as Boolean {
    var info = Protocol.decodeMacInfo([1, 2, 3, 4, 5, 6, 7, 8]b);
    Test.assert(info != null);
    Test.assertEqual(info[:name], "");
    return true;
}

(:test)
function decodeMacInfoUtf8Name(logger as Logger) as Boolean {
    var info = Protocol.decodeMacInfo([1, 2, 3, 4, 5, 6, 7, 8, 0xD0, 0x9C, 0xD0, 0xB0, 0xD0, 0xBA]b);
    Test.assert(info != null);
    Test.assertEqual(info[:name], "Мак");
    return true;
}
