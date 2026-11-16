import 'package:image_picker/image_picker.dart';

import 'scan_image_cropper.dart';

class GalleryPickerService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    return cropImageToScanAspect(image.path);
  }
}
