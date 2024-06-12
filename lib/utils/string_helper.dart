class StringHelper {
  static String unicodeToUtf8(String unicodeString) {
    List<String> unicodeChars = unicodeString.split(r'\u');
    String utf8String = '';
    for (int i = 1; i < unicodeChars.length; i++) {
      String hex = unicodeChars[i];
      int codePoint = int.parse(hex, radix: 16);
      utf8String += String.fromCharCode(codePoint);
    }
    return utf8String;
  }
}
