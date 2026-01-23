import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mychatolic_app/pages/final_photo_page.dart';

class PhotoPostFlow {
  static final ImagePicker _picker = ImagePicker();

  /// Initiates the Photo Post Flow: Picker -> Cropper -> Final Caption Screen
  static Future<void> start(BuildContext context, {required bool fromCamera}) async {
    try {
      // 1. Pick Image
      final XFile? pickedFile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 100, // High quality for feed
      );

      if (pickedFile == null) return; // User cancelled

      // 2. Crop Image (Strict 4:5)
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 5),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true, // Enforce 4:5
            hideBottomControls: true, 
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return; // User cancelled crop

      // 3. Navigate to Final Screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalPhotoCaptionPage(imageFile: File(croppedFile.path)),
          ),
        );
      }

    } catch (e) {
      debugPrint("Photo Flow Error: $e");
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }
}
