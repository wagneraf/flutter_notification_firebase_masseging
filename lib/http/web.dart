import 'dart:convert';
import 'package:meetups/models/device.dart';
import 'package:meetups/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://192.168.0.15:8080/api';

Future<List<Event>> getAllEvents() async {
  final response = await http
      .get(Uri.parse('$baseUrl/events'));

  if (response.statusCode == 200) {
    final List<dynamic> decodedJson = jsonDecode(response.body);
    return decodedJson.map((dynamic json) => Event.fromJson(json)).toList();
  }
  else {
    throw Exception('Falha ao carregar os eventos');
  }
}

void sendDevice(Device device) async{
  final response = await http.post(Uri.parse('$baseUrl/devices'),
    headers: <String, String> {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
        'token': device.token ?? '',
        'modelo': device.model ?? '',
        'marca' : device.brand ?? '',
      })
  );

  if(response.statusCode == 200){
    SharedPreferences pref = await SharedPreferences.getInstance();

    pref.setString('pushToken', device.token!);
    pref.setBool('sentToken', true);
  }else{
    throw Exception('Falha ao criar  o dispositivo.');
  }
}
