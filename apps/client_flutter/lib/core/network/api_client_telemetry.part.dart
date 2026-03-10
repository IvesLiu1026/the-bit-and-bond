part of 'api_client.dart';

Future<void> _apiClientSendTelemetryEvents(
  ApiClient client, {
  required List<TelemetryEventPayload> events,
  bool allowPublic = false,
}) async {
  if (events.isEmpty) {
    return;
  }
  final payload = <String, dynamic>{
    'events': events.map((event) => event.toJson()).toList(growable: false),
  };

  if (allowPublic) {
    final response = await client._httpClient
        .post(
          Uri.parse('${client.baseUrl}/api/v1/telemetry/public-events'),
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));
    client._parseResponse(response);
    return;
  }

  await client._authedPost(
    '/api/v1/telemetry/events',
    payload,
    role: _AuthRole.any,
  );
}
