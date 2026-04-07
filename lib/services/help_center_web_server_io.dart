import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class HelpCenterWebServer {
  HelpCenterWebServer._();

  static final HelpCenterWebServer instance = HelpCenterWebServer._();

  HttpServer? _server;
  Uri? _baseUri;

  Future<Uri> ensureStarted() async {
    final Uri? existing = _baseUri;
    if (existing != null) {
      return existing;
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
    _baseUri = Uri.parse(
      'http://${_server!.address.host}:${_server!.port}/help-center/',
    );
    return _baseUri!;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.path == '/help-center/' ||
          request.uri.path == '/help-center') {
        final String html = await rootBundle.loadString(
          'assets/help_center/index.html',
        );
        request.response.headers.contentType = ContentType.html;
        request.response.write(html);
      } else if (request.uri.path == '/') {
        request.response.statusCode = HttpStatus.movedPermanently;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          '/help-center/',
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
    } finally {
      await request.response.close();
    }
  }
}
