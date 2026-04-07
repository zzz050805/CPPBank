class HelpCenterWebServer {
  HelpCenterWebServer._();

  static final HelpCenterWebServer instance = HelpCenterWebServer._();

  Future<Uri> ensureStarted() async {
    return Uri.parse('about:blank');
  }
}
