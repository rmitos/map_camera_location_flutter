import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';

import '../map_camera_flutter.dart';

class MapCameraController extends GetxController with StateMixin {
  late CameraController cameraController;
  var flashMode = FlashMode.off.obs;

  Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final _markerId = const MarkerId("map_marker");
  var markers = RxSet<Marker>().obs;
  var showProgress = false.obs;
  var latLong = const LatLng(0.0, 0.0).obs;

  final dateFormat = DateFormat("dd MMM yyyy hh:mm a");
  final dateTime = "".obs;

  final latitudeServer = "".obs;
  final longitudeServer = "".obs;
  final subLocation = "".obs;

  final takingPic = false.obs;
  final errorMessage = 'Please wait to capture location'.obs;

  @override
  Future onInit() async {
    await _setCamera();
    super.onInit();
  }

  @override
  void onClose() {
    cameraController.dispose();
    _mapController = Completer();
    super.onClose();
  }

  Future _setCamera() async {
    final cameras = await availableCameras();
    // Initialize the camera controller
    cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await cameraController.initialize();
    change(null, status: RxStatus.success());
  }

  void onMapCreated(GoogleMapController controller) async {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
      _getLocation();
    }
  }

  Future _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // If location services are disabled, throw an exception
      subLocation.value = 'Location services are disabled.';
      return;
    }
    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // If location permission is denied, request it
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // If location permission is still denied, throw an exception
        subLocation.value = 'Location permissions are denied';
        return;
      }
    }

    // Check if location permission is permanently denied
    if (permission == LocationPermission.deniedForever) {
      // Throw an exception if location permission is permanently denied
      subLocation.value = 'Location permissions are permanently denied, Use settings to enable.';
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, //move the device 5 meters to update location
    );

    StreamSubscription<Position> positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position? position) async {
      if (position != null) {
        errorMessage.value = "";
        final latLng = LatLng(position.latitude, position.longitude);

        markers.value.clear();
        markers.value.add(Marker(markerId: _markerId, position: latLng));

        final GoogleMapController controller = await _mapController.future;
        controller.moveCamera(CameraUpdate.newLatLng(latLng));

        await _updatePosition(position);
      }
    });
  }

  Future<void> _updatePosition(Position position) async {
    try {
      //update date time
      dateTime.value = dateFormat.format(await NTP.now());

      // Retrieve the placeMarks for the current position
      final placeMarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placeMarks.isNotEmpty) {
        final placeMark = placeMarks.first;

        latitudeServer.value = position.latitude.toString();
        longitudeServer.value = position.longitude.toString();
        subLocation.value = "${placeMark.street ?? ""}, ${placeMark.subLocality ?? ""}, ${placeMark.locality ?? ""}, ${placeMark.subAdministrativeArea ?? ""}, ${placeMark.administrativeArea ?? ""}, ${placeMark.country ?? ""}-${placeMark.postalCode ?? ""}";

        if (kDebugMode) {
          print("Latitude: $latitudeServer, Longitude: $longitudeServer, Address:: ${placeMark.toString()}");
        }
      } else {
        // Handle case when no placeMark is available
        latitudeServer.value = "";
        longitudeServer.value = "";
        subLocation.value = 'No address found.';
      }
    } catch (e) {
      // Handle any errors that occurred during location retrieval
      latitudeServer.value = "";
      longitudeServer.value = "";
      subLocation.value = 'Error retrieving address.';
    }
  }

  Future<void> setFlash() async {
    if (flashMode.value == FlashMode.off) {
      await cameraController.setFlashMode(FlashMode.torch);
      flashMode.value = FlashMode.torch;
    } else {
      await cameraController.setFlashMode(FlashMode.off);
      flashMode.value = FlashMode.off;
    }
  }
}
