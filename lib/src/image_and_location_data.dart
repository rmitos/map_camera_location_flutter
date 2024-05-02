import 'dart:typed_data';

typedef ImageAndLocationCallback = void Function(ImageAndLocationData data);

class ImageAndLocationData {
  final Uint8List? image;
  final String latitude;
  final String longitude;
  //final String? locationName;
  //final String? subLocation;

  ImageAndLocationData({
    required this.image,
    required this.latitude,
    required this.longitude,
    //required this.locationName,
    //required this.subLocation,
  });
}
