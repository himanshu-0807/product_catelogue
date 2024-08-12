import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AddProductForm extends StatefulWidget {
  const AddProductForm({super.key});

  @override
  State<AddProductForm> createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  TextEditingController name = TextEditingController();
  TextEditingController rate = TextEditingController();
  TextEditingController desc = TextEditingController();
  String itemType = 'Goods'; // Default value for radio buttons

  List<File> _images = [];
  List<Uint8List> _processedImages = [];

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker _picker = ImagePicker();
    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null) {
      setState(() {
        _images.addAll(images.map((image) => File(image.path)).toList());
      });
    }
  }

  Future<void> _uploadImages() async {
    for (var imageFile in _images) {
      try {
        var uri = Uri.parse('http://192.168.123.161:5000/remove-background');
        var request = http.MultipartRequest('POST', uri)
          ..files.add(http.MultipartFile(
            'file',
            imageFile.readAsBytes().asStream(),
            imageFile.lengthSync(),
            filename: imageFile.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          ));

        var response = await request.send();

        if (response.statusCode == 200) {
          var bytes = await response.stream.toBytes();
          setState(() {
            _processedImages.add(bytes);
          });
          print('Image uploaded and background removed successfully');
        } else {
          var responseData = await response.stream.bytesToString();
          print(
              'Failed to upload image. Status code: ${response.statusCode}, Response: $responseData');
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  void _showPickedImages() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 400.h, // Adjust height as needed
          child: Column(
            children: [
              Text(
                'Picked Images (${_images.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Image.file(
                        _images[index],
                        width: 50.w,
                        height: 50.h,
                        fit: BoxFit.cover,
                      ),
                      title: Text('Image ${index + 1}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _images.removeAt(index);
                            _processedImages.removeAt(index);
                          });
                        },
                      ),
                      onTap: () {
                        // Handle image preview or other actions
                      },
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Close'),
              ),
              SizedBox(height: 10.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the current bottom sheet
                  _showImageSourcePicker(); // Show image source picker
                },
                child: Text('Add More Images'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take a photo'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Upload from gallery'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget textFieldWithLabel(
      String heading, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
          ),
          SizedBox(
            height: 5.h,
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Product')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Column(
            children: [
              RadioListTile(
                title: Text('Goods'),
                value: 'Goods',
                groupValue: itemType,
                onChanged: (val) {
                  setState(() {
                    itemType = val!;
                  });
                },
              ),
              RadioListTile(
                title: Text('Service'),
                value: 'Service',
                groupValue: itemType,
                onChanged: (val) {
                  setState(() {
                    itemType = val!;
                  });
                },
              ),
              SizedBox(
                height: 10.h,
              ),
              InkWell(
                onTap: () {
                  if (_images.isNotEmpty) {
                    _showPickedImages(); // Show images sheet if images are picked
                  } else {
                    _showImageSourcePicker(); // Show image source picker if no images are picked
                  }
                },
                child: Container(
                  height: 100.h,
                  width: 120.w,
                  decoration: BoxDecoration(
                    border: Border.all(),
                  ),
                  child: Center(
                    child: Text('${_images.length} images picked'),
                  ),
                ),
              ),
              textFieldWithLabel('Name*', 'Name', name),
              textFieldWithLabel('Unit*', 'Name', name),
              textFieldWithLabel('Select Category*', 'Category', desc),
              textFieldWithLabel('HSN', 'Category', desc),
              SizedBox(height: 20.h),
              // ElevatedButton(
              //   onPressed: () {
              //     if (_images.isNotEmpty) {
              //       _uploadImages();
              //     } else {
              //       print('No images to upload');
              //     }
              //   },
              //   child: Text('Upload Images for Background Removal'),
              // ),
              SizedBox(height: 20.h),
              SizedBox(
                height: 400.h, // Define a height for the ListView
                child: ListView.builder(
                  itemCount: _processedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(
                          8.0), // Add some padding for better spacing
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Image.memory(
                              _processedImages[index],
                              width: 150.w, // Adjust the width as needed
                              height: 150.h, // Adjust the height as needed
                              fit: BoxFit.cover,
                            ),
                            SizedBox(
                                height: 5
                                    .h), // Add some space between the image and text
                            Text(
                              'Processed Image ${index + 1}',
                              style: TextStyle(
                                  fontSize: 14.sp, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
