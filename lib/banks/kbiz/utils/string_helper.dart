class StringHelper {
  static String transferorConvert(String transferor) {
    final ret = transferor.replaceAll('-', '').replaceFirst(RegExp(r'^x+'), '');
    return ret;
  }
}
