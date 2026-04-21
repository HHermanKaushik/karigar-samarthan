import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoInput extends StatelessWidget {
  final File? imageFile;
  final Function(File pickedFile) onImagePicked;

  const PhotoInput({
    super.key,
    this.imageFile,
    required this.onImagePicked,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
        );

        if (photo != null) {
          onImagePicked(File(photo.path));
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          image: imageFile != null
              ? DecorationImage(image: FileImage(imageFile!), fit: BoxFit.cover)
              : null,
        ),
        child: imageFile == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 64),
                  SizedBox(height: 16),
                  Text("Tap to Take Photo", style: TextStyle(fontSize: 18)),
                ],
              )
            : null,
      ),
    );
  }
}