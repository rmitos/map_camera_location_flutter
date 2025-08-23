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

class MapCameraController extends GetxController with StateMixin, WidgetsBindingObserver {
  var isControllerActive = true;
  late CameraController cameraController;
  var flashMode = FlashMode.off.obs;

  late List<CameraDescription> cameras;
  var selectedCameraIndex = 0.obs;

  GoogleMapController? googleMapController;
  StreamSubscription<Position>? positionStream;
  final _markerId = const MarkerId("map_marker");
  var markers = <Marker>{};
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
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    await _setCamera();
  }

  @override
  void onClose() {
    isControllerActive = false;
    WidgetsBinding.instance.removeObserver(this);
    positionStream?.cancel();
    if (cameraController.value.isInitialized) {
      cameraController.dispose();
    }
    googleMapController?.dispose();

    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!isControllerActive) {
      return;
    }

    // It's possible this method is called before the camera is fully initialized.
    // So, we first check if the camera controller's value indicates it's ready.
    // This safely avoids a LateInitializationError.
    if (!cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Release the camera when the app is in the background or paused.
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // When the app is resumed, re-initialize the camera.
      _setCamera();
    }
  }

  Future _setCamera() async {
    cameras = await availableCameras();
    if (cameras.isEmpty) {
      change(null, status: RxStatus.error("No cameras found."));
      return;
    }
    // Initialize the camera controller
    cameraController = CameraController(
      cameras[selectedCameraIndex.value],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await cameraController.initialize();
      if(isControllerActive) {
        change(null, status: RxStatus.success());
      }
    } catch (e) {
      if(isControllerActive) {
        change(null, status: RxStatus.error("Failed to initialize camera: $e"));
      }
    }
  }

  void onMapCreated(GoogleMapController controller) {
    googleMapController = controller; // Always update with the latest controller
    // Only start listening for location if we haven't already.
    if (positionStream == null) {
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
      distanceFilter: 0, //notify all movements, otherwise, location won't pickup on second call.
    );

    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position? position) async {
      if (position != null) {
        errorMessage.value = "";
        latLong.value = LatLng(position.latitude, position.longitude);

        markers.clear();
        markers.add(Marker(markerId: _markerId, position: latLong.value));

        final camPos = CameraPosition(target: latLong.value, zoom: 17);
        await googleMapController?.animateCamera(CameraUpdate.newCameraPosition(camPos));

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

  Future<void> switchCamera() async {
    if (cameras.length < 2) return; // Do nothing if there's only one camera

    // Show a loading state while switching
    change(null, status: RxStatus.loading());

    // Cycle to the next camera index
    selectedCameraIndex.value = (selectedCameraIndex.value + 1) % cameras.length;

    // Dispose the old controller to release the camera
    await cameraController.dispose();

    // Set up the new camera
    await _setCamera();
  }

  void stopLocationStream() {
    positionStream?.cancel();
    positionStream = null; // Set to null to prevent further cancellation attempts
    if (kDebugMode) {
      print("Geolocation stream stopped by user.");
    }
  }
}
