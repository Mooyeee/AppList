import 'dart:math';
import 'dart:typed_data';

class AndroidXMLDecompress {
  // decompressXML -- Parse the 'compressed' binary form of Android XML docs
  // such as for AndroidManifest.xml in .apk files
  static int endDocTag = 0x00100101;
  static int startTag = 0x00100102;
  static int endTag = 0x00100103;

  static void prt(String str) {
    //System.err.print(str);
  }

  static String decompressXML(Uint8List xml) {
    StringBuffer finalXML = new StringBuffer();

    // Compressed XML file/bytes starts with 24x bytes of data,
    // 9 32 bit words in little endian order (LSB first):
    // 0th word is 03 00 08 00
    // 3rd word SEEMS TO BE: Offset at then of StringTable
    // 4th word is: Number of strings in string table
    // WARNING: Sometime I indiscriminently display or refer to word in
    // little endian storage format, or in integer format (ie MSB first).
    int numbStrings = LEW(xml, 4 * 4);

    // StringIndexTable starts at offset 24x, an array of 32 bit LE offsets
    // of the length/string data in the StringTable.
    int sitOff = 0x24; // Offset of start of StringIndexTable

    // StringTable, each string is represented with a 16 bit little endian
    // character count, followed by that number of 16 bit (LE) (Unicode)
    // chars.
    int stOff = sitOff + numbStrings * 4; // StringTable follows
    // StrIndexTable

    // XMLTags, The XML tag tree starts after some unknown content after the
    // StringTable. There is some unknown data after the StringTable, scan
    // forward from this point to the flag for the start of an XML start
    // tag.
    int xmlTagOff = LEW(xml, 3 * 4); // Start from the offset in the 3rd
    // word.
    // Scan forward until we find the bytes: 0x02011000(x00100102 in normal
    // int)
    for (int ii = xmlTagOff; ii < xml.length - 4; ii += 4) {
      if (LEW(xml, ii) == startTag) {
        xmlTagOff = ii;
        break;
      }
    } // end of hack, scanning for start of first start tag

    // XML tags and attributes:
    // Every XML start and end tag consists of 6 32 bit words:
    // 0th word: 02011000 for startTag and 03011000 for endTag
    // 1st word: a flag?, like 38000000
    // 2nd word: Line of where this tag appeared in the original source file
    // 3rd word: FFFFFFFF ??
    // 4th word: StringIndex of NameSpace name, or FFFFFFFF for default NS
    // 5th word: StringIndex of Element Name
    // (Note: 01011000 in 0th word means end of XML document, endDocTag)

    // Start tags (not end tags) contain 3 more words:
    // 6th word: 14001400 meaning??
    // 7th word: Number of Attributes that follow this tag(follow word 8th)
    // 8th word: 00000000 meaning??

    // Attributes consist of 5 words:
    // 0th word: StringIndex of Attribute Name's Namespace, or FFFFFFFF
    // 1st word: StringIndex of Attribute Name
    // 2nd word: StringIndex of Attribute Value, or FFFFFFF if ResourceId
    // used
    // 3rd word: Flags?
    // 4th word: str ind of attr value again, or ResourceId of value

    // TMP, dump string table to tr for debugging
    // tr.addSelect("strings", null);
    // for (int ii=0; ii<numbStrings; ii++) {
    // // Length of string starts at StringTable plus offset in StrIndTable
    // String str = compXmlString(xml, sitOff, stOff, ii);
    // tr.add(String.valueOf(ii), str);
    // }
    // tr.parent();

    // Step through the XML tree element tags and attributes
    int off = xmlTagOff;
    int indent = 0;
    int startTagLineNo = -2;
    while (off < xml.length) {
      int tag0 = LEW(xml, off);
      // int tag1 = LEW(xml, off+1*4);
      int lineNo = LEW(xml, off + 2 * 4);
      // int tag3 = LEW(xml, off+3*4);
      int nameNsSi = LEW(xml, off + 4 * 4);
      int nameSi = LEW(xml, off + 5 * 4);

      if (tag0 == startTag) {
        // XML START TAG
        int tag6 = LEW(xml, off + 6 * 4); // Expected to be 14001400
        int numbAttrs = LEW(xml, off + 7 * 4); // Number of Attributes
        // to follow
        // int tag8 = LEW(xml, off+8*4); // Expected to be 00000000
        off += 9 * 4; // Skip over 6+3 words of startTag data
        String name = compXmlString(xml, sitOff, stOff, nameSi);
        // tr.addSelect(name, null);
        startTagLineNo = lineNo;

        // Look for the Attributes
        StringBuffer sb = new StringBuffer();
        for (int ii = 0; ii < numbAttrs; ii++) {
          int attrNameNsSi = LEW(xml, off); // AttrName Namespace Str
          // Ind, or FFFFFFFF
          int attrNameSi = LEW(xml, off + 1 * 4); // AttrName String
          // Index
          int attrValueSi = LEW(xml, off + 2 * 4); // AttrValue Str
          // Ind, or
          // FFFFFFFF
          int attrFlags = LEW(xml, off + 3 * 4);
          int attrResId = LEW(xml, off + 4 * 4); // AttrValue
          // ResourceId or dup
          // AttrValue StrInd
          off += 5 * 4; // Skip over the 5 words of an attribute

          String attrName = compXmlString(xml, sitOff, stOff, attrNameSi);

          String attrValue = "";
          if (attrValueSi != -1) {
            attrValue = compXmlString(xml, sitOff, stOff, attrValueSi);
          } else {
            if (attrResId == -1)
              attrValue = "resourceID 0x" + attrResId.toRadixString(16);
            else
              attrValue =
                  int.parse(attrResId.toRadixString(16), radix: 16).toString();

            //System.out.println(attrName + " >>> " + attrValue.split("0x")[1]);
          }

          // attrValue = Integer.valueOf(Integer.toHexString(attrResId), 16).intValue();

          sb.write(" " + attrName + "=\"" + attrValue + "\"");
          // tr.add(attrName, attrValue);
        }
        finalXML.write("<" + name + sb.toString() + ">");
        prtIndent(indent, "<" + name + sb.toString() + ">");
        indent++;
      } else if (tag0 == endTag) {
        // XML END TAG
        indent--;
        off += 6 * 4; // Skip over 6 words of endTag data
        String name = compXmlString(xml, sitOff, stOff, nameSi);
        finalXML.write("</" + name + ">");
        prtIndent(
            indent,
            "</" +
                name +
                "> (line " +
                startTagLineNo.toString() +
                "-" +
                lineNo.toString() +
                ")");
        // tr.parent(); // Step back up the NobTree

      } else if (tag0 == endDocTag) {
        // END OF XML DOC TAG
        break;
      } else {
        prt("  Unrecognized tag code '" +
            tag0.toRadixString(16) +
            "' at offset " +
            off.toString());
        break;
      }
    } // end of while loop scanning tags and attributes of XML tree
    //prt("    end at offset " + off);
    return finalXML.toString();
  } // end of decompressXML

  static String compXmlString(
      Uint8List xml, int sitOff, int stOff, int strInd) {
    if (strInd < 0) return "";
    int strOff = stOff + LEW(xml, sitOff + strInd * 4);
    return compXmlStringAt(xml, strOff);
  }

  static String spaces = "                                             ";

  static void prtIndent(int indent, String str) {
    prt(spaces.substring(0, min(indent * 2, spaces.length)) + str);
  }

  // compXmlStringAt -- Return the string stored in StringTable format at
  // offset strOff. This offset points to the 16 bit string length, which
  // is followed by that number of 16 bit (Unicode) chars.
  static String compXmlStringAt(Uint8List arr, int strOff) {
    int strLen = arr[strOff + 1] << 8 & 0xff00 | arr[strOff] & 0xff;
    Uint8List chars = new Uint8List(strLen);
    for (int ii = 0; ii < strLen; ii++) {
      chars[ii] = arr[strOff + 2 + ii * 2];
    }
    return new String.fromCharCodes(chars); // Hack, just use 8 byte chars
  } // end of compXmlStringAt

  // LEW -- Return value of a Little Endian 32 bit word from the byte array
  // at offset off.
  static int LEW(Uint8List arr, int off) {
    int c = 0;
    try {
      c = arr[off + 3] << 24 & 0xff000000 |
          arr[off + 2] << 16 & 0xff0000 |
          arr[off + 1] << 8 & 0xff00 |
          arr[off] & 0xFF;
    } catch (e) {
      return -1;
    }

    if (c < -2147483648 || c > 2147483647)
      return -1;
    else
      return c;
  } // end of LEW
}
