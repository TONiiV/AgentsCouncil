import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../app/config.dart';

/// WebSocket service for real-time debate updates
class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _heartbeatTimer;
  String? _currentDebateId;
  
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  
  bool get isConnected => _channel != null;
  
  void connect(String debateId) {
    if (_currentDebateId == debateId && _channel != null) {
      return; // Already connected to this debate
    }
    
    disconnect();
    _currentDebateId = debateId;
    
    final uri = Uri.parse('${ApiConfig.wsUrl}/debates/$debateId');
    _channel = WebSocketChannel.connect(uri);
    
    _channel!.stream.listen(
      (message) {
        if (message == 'heartbeat' || message == 'pong') {
          return; // Ignore heartbeat responses
        }
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _eventController.add(data);
        } catch (e) {
          print('WebSocket parse error: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _reconnect();
      },
      onDone: () {
        print('WebSocket closed');
        _reconnect();
      },
    );
    
    // Start heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _sendPing(),
    );
  }
  
  void _sendPing() {
    try {
      _channel?.sink.add('ping');
    } catch (e) {
      print('Ping error: $e');
    }
  }
  
  void _reconnect() {
    if (_currentDebateId != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentDebateId != null) {
          connect(_currentDebateId!);
        }
      });
    }
  }
  
  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _currentDebateId = null;
  }
  
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
