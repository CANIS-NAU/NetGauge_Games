import 'package:flutter/material.dart';
import 'location_service.dart';

class LocationTestPage extends StatefulWidget{
  const LocationTestPage({super.key});

  @override
  State<LocationTestPage> createState() => _LocationTestPageState();
}

class _LocationTestPageState extends State<LocationTestPage>
{
  String _locationMessage = 'Press the button to get location';

  Future<void> _getLocation() async
  {
    try 
    {
      final position = await determinePosition();
      setState(()
      {
        _locationMessage = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
      });
    } catch(e) {
      setState((){
        _locationMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Service Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _getLocation,
              child: const Text('GetCurrentLocation'),
            ),
            const SizedBox(height: 20),
            Text(
              _locationMessage, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}