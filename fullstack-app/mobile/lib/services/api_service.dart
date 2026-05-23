import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agent.dart';
import '../models/message.dart';
import '../config/api_config.dart';

class ApiService {
  final String _base = ApiConfig.baseUrl;

  Future<List<Agent>> fetchAgents() async {
    final response = await http
        .get(Uri.parse('$_base/agents'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load agents (${response.statusCode})');
    }

    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => Agent.fromJson(j as Map<String, dynamic>)).toList();
  }

  Stream<String> streamChat({
    required String agentSlug,
    required String message,
    required List<Message> history,
  }) async* {
    final request = http.Request('POST', Uri.parse('$_base/chat'));
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      'agentSlug': agentSlug,
      'message': message,
      'history': history.map((m) => m.toJson()).toList(),
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final parsed = jsonDecode(data) as Map<String, dynamic>;
              if (parsed['text'] != null) yield parsed['text'] as String;
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
