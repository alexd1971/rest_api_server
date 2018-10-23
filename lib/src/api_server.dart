import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

/// Rest Api server
///
///
class ApiServer {
  final InternetAddress _address;
  final int _port;
  final shelf.Handler _handler;

  HttpServer _httpServer;

  /// Creates REST API-server
  ///
  /// [address] - address to listen
  /// [port] - port to listen
  /// [handler] - request hadler
  ApiServer({InternetAddress address, int port, shelf.Handler handler})
      : assert(address != null),
        assert(port != null),
        assert(handler != null),
        _address = address,
        _port = port,
        _handler = handler;

  /// Starts server
  Future start() async {
    _httpServer = await io.serve(_handler, _address, _port);
    print(
        'API-server is listening on ${_httpServer.address.host}:${_httpServer.port}');
  }

  /// Stops server
  Future stop() {
    return _httpServer.close();
  }

  /// Server ip address
  InternetAddress get address {
    if (_httpServer == null) {
      throw (Exception('Server is not started'));
    } else {
      return _httpServer.address;
    }
  }

  /// Server port
  int get port {
    if (_httpServer == null) {
      throw (Exception('Server is not started'));
    } else {
      return _httpServer.port;
    }
  }
}
