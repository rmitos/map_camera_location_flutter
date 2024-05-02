import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/state_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_camera_flutter/src/map_camera_controller.dart';
import 'dart:ui' as ui;

import 'image_and_location_data.dart';

class MapCameraLocation extends StatelessWidget {
  MapCameraLocation({super.key, this.onImageCaptured});

  final ImageAndLocationCallback? onImageCaptured;

  final globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: GetBuilder<MapCameraController>(
        init: MapCameraController(),
        builder: (controller) {
          return controller.obx(
            (_) => Column(
              children: [
                RepaintBoundary(
                  key: globalKey,
                  child: Stack(
                    children: [
                      CameraPreview(controller.cameraController),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 130,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: SizedBox(
                                      width: 120,
                                      child: Padding(
                                          padding: const EdgeInsets.all(0),
                                          child: Obx(
                                            () => GoogleMap(
                                              mapType: MapType.satellite,
                                              compassEnabled: false,
                                              mapToolbarEnabled: false,
                                              liteModeEnabled: false,
                                              myLocationButtonEnabled: false,
                                              rotateGesturesEnabled: false,
                                              scrollGesturesEnabled: false,
                                              zoomControlsEnabled: false,
                                              zoomGesturesEnabled: false,
                                              markers: controller.markers.value,
                                              initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0), zoom: 15),
                                              onMapCreated: controller.onMapCreated,
                                            ),
                                          )),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(0), color: Colors.black.withOpacity(0.5)),
                                      child: Obx(() => Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Latitude: ${controller.latitudeServer.value.isEmpty ? "Loading.." : controller.latitudeServer.value}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                "Longitude: ${controller.longitudeServer.value.isEmpty ? "Loading.." : controller.longitudeServer.value}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                controller.dateTime.value.isEmpty ? "Loading.." : controller.dateTime.value,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                controller.subLocation.value.isEmpty ? "Loading .." : controller.subLocation.value,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(
                        () => IconButton(
                          icon: Icon(controller.flashMode.value == FlashMode.off ? Icons.flash_off_outlined : Icons.flash_on_outlined, size: 32, color: Colors.white),
                          onPressed: () async {
                            await controller.setFlash();
                          },
                        ),
                      ),
                      Obx(
                        () => controller.errorMessage.isNotEmpty
                            ? Expanded(
                                child: Container(
                                  color: Colors.red,
                                  padding: const EdgeInsets.all(2),
                                  child: Text(controller.errorMessage.value, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Obx(
                        () => controller.takingPic.value
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const Icon(Icons.camera_alt, size: 48, color: Colors.white),
                                onPressed: () async {
                                  await takeScreenshot(controller);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onLoading: const Center(child: CircularProgressIndicator()),
            onError: (err) => Container(
              padding: const EdgeInsets.all(16),
              child: Text("ERROR : $err"),
            ),
          );
        },
      ),
    );
  }

  Future<void> takeScreenshot(MapCameraController controller) async {
    controller.errorMessage.value = '';
    if (controller.latitudeServer.value.isEmpty || controller.longitudeServer.value.isEmpty) {
      controller.errorMessage.value = "Please wait to capture the location.";
      return;
    }

    if (controller.dateTime.value.isEmpty) {
      controller.errorMessage.value = "Please wait to capture date and time.";
      return;
    }

    //hide the capture button
    controller.takingPic.value = true;

    // Get the render boundary of the widget
    final RenderRepaintBoundary boundary = globalKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // Capture the screen as an image
    ui.Image image = await boundary.toImage();

    // Convert the image to bytes in PNG format
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    // Check if the file exists
    bool isExists = pngBytes.isNotEmpty;

    if (isExists) {
      // Trigger the image captured callback
      if (onImageCaptured != null) {
        ImageAndLocationData data = ImageAndLocationData(
          image: pngBytes,
          latitude: controller.latitudeServer.value,
          longitude: controller.longitudeServer.value,
          //locationName: locationName.value,
          //subLocation: subLocation,
        );
        onImageCaptured!(data);
      }
    } else {
      debugPrint('File does not exist');
    }
  }
}
