import 'package:flutter/material.dart';
import 'location_service.dart';

// THIS WAS A DEBUG FILE. IT AND CODE REFERENCING IT CAN BE REMOVED WHEN PROJECT IS COMPLETE
class LocationTestPage extends StatefulWidget{
  const LocationTestPage({super.key});

  @override
  State<LocationTestPage> createState() => _LocationTestPageState();
}

class _LocationTestPageState extends State<LocationTestPage>
{
  String _locationDataMessage = 'Press the button to get location';

  Future<void> _getLocationData() async
  {
    try 
    {
      final locationData = await determineLocationData();
      setState(()
      {
        final lat = locationData.position.latitude.toStringAsFixed(6);
        final lng = locationData.position.longitude.toStringAsFixed(6);
        final heading = locationData.heading != null? '${locationData.heading!.toStringAsFixed(2)}°': 'N/A';

        _locationDataMessage = 'Lat: $lat\nLng: $lng\nHeading: $heading';
      });
    } catch(e) {
      setState((){
        _locationDataMessage = 'Error: $e';
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
              onPressed: _getLocationData,
              child: const Text('GetCurrentLocation'),
            ),
            const SizedBox(height: 20),
            Text(
              _locationDataMessage, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}