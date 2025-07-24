import 'package:flutter/material.dart';
import 'package:map_camera_flutter/map_camera_flutter.dart';

class CameraMapPage extends StatelessWidget {
  const CameraMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text("Camera Map"),
        ),
        body: MapCameraLocation(
          onImageCaptured: (ImageAndLocationData data) {
            print('Captured image path: ${data.image?.length}');
            print('Latitude: ${data.latitude}');
            print('Longitude: ${data.longitude}');
          },
        ));
  }
}
