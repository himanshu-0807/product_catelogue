import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> categories = [];
  String? selectedCategoryId;
  List<dynamic> items = [];
  bool isLoadingCategories = false;
  bool isLoadingItems = false;
  Map<String, Uint8List> itemImages = {}; // Add this line

  bool isSelectionMode = false;
  Set<String> selectedItems = {};

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });
    String? response = await getCategoriesName();
    if (response != null) {
      var data = json.decode(response);
      setState(() {
        categories = data['categories']
            .where((category) => category['name'] != 'ROOT')
            .toList();
      });
    }
    setState(() {
      isLoadingCategories = false;
    });
  }

  Future<String> getAccessTokenForCategories() async {
    String refresh_token =
        '1000.66150dacde21bf94307edf1ef31a3377.9aaa1f5f26c9a318ea9d9ef26db02dda';
    String client_id = '1000.8D1CXTZ1XTCJOLZ5SNR25Z9ULKYKCC';
    String client_secret = '07eda3e97bdbf586e973657f1c58bb8d9214d64d8f';
    String redirect_uri = 'https://divinzo.com/';
    String grant_type = 'refresh_token';

    Uri url = Uri.parse("https://accounts.zoho.in/oauth/v2/token");
    Map<String, String> body = {
      'refresh_token': refresh_token,
      'client_id': client_id,
      'client_secret': client_secret,
      'redirect_uri': redirect_uri,
      'grant_type': grant_type
    };

    try {
      http.Response response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        String access_token = responseData['access_token'];
        return access_token;
      } else {
        return '';
      }
    } catch (e) {
      print('Error: $e');
      return '';
    }
  }

  Future<String?> getCategoriesName() async {
    String access_token = await getAccessTokenForCategories();
    String org_id = '60026604390';

    Uri url = Uri.parse("https://commerce.zoho.in/store/api/v1/categories");
    Map<String, String>? headers = {
      'Authorization': 'Zoho-oauthtoken $access_token',
      'X-com-zoho-store-organizationid': org_id
    };

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      print(response.statusCode);
      return null;
    }
  }

  Future<String> getAccessTokenForItems() async {
    String refresh_token =
        '1000.ddd78e1939f421f47e6ec50a1445291b.bf05a2e8b589edc596346b6982132ad3';
    String client_id = '1000.8D1CXTZ1XTCJOLZ5SNR25Z9ULKYKCC';
    String client_secret = '07eda3e97bdbf586e973657f1c58bb8d9214d64d8f';
    String redirect_uri = 'https://divinzo.com/';
    String grant_type = 'refresh_token';

    Uri url = Uri.parse("https://accounts.zoho.in/oauth/v2/token");
    Map<String, String> body = {
      'refresh_token': refresh_token,
      'client_id': client_id,
      'client_secret': client_secret,
      'redirect_uri': redirect_uri,
      'grant_type': grant_type
    };

    try {
      http.Response response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        String access_token = responseData['access_token'];
        return access_token;
      } else {
        return '';
      }
    } catch (e) {
      print('Error: $e');
      return '';
    }
  }

  Future<void> getFilteredItems(String categoryId) async {
    setState(() {
      isLoadingItems = true;
    });

    String accessToken = await getAccessTokenForItems();
    String orgId = "60026604390";

    Uri url = Uri.parse(
        "https://www.zohoapis.in/books/v3/items?category_id=$categoryId&organization_id=$orgId");

    Map<String, String> headers = {
      'Authorization': 'Zoho-oauthtoken $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        var itemsData = data['items'] as List;

        setState(() {
          items = itemsData;
        });

        for (var item in itemsData) {
          await getImageUrls(item['item_id']);
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        isLoadingItems = false;
      });
    }
  }

  Future<void> getImageUrls(String itemId) async {
    String org_id = '60026604390';
    String access_token = await getAccessTokenForItems();

    Uri url = Uri.parse(
        'https://books.zoho.in/api/v3/items/$itemId/image?organization_id=$org_id');
    Map<String, String> headers = {
      "Authorization": "Zoho-oauthtoken $access_token"
    };
    try {
      http.Response response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        var imageBytes = response.bodyBytes;
        setState(() {
          itemImages[itemId] = imageBytes; // Store the image bytes
        });
      } else {
        setState(() {
          isLoadingItems = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Image Unable to load')));
      }
    } catch (e) {
      print('Error fetching image: $e');
    }
  }

  //////////////////////////// sharing items ////////////////////////////
  String _generateUniqueId() {
    var rng = Random();
    var code = (rng.nextDouble() * 900000).toInt() + 100000;
    return code.toString();
  }

  void _uploadSelectedItems() async {
    String uniqueId = _generateUniqueId();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select items to upload.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Uploading items...'),
            ],
          ),
        );
      },
    );

    List<Map<String, dynamic>> selectedItemsData = [];
    for (var item in items) {
      if (selectedItems.contains(item['item_id'])) {
        String imageUrl =
            await _uploadImageToFirebase(item['item_id'], uniqueId);
        selectedItemsData.add({
          'itemId': item['item_id'],
          'name': item['name'],
          'rate': item['rate'],
          'description': item['description'],
          'imageUrl': imageUrl,
        });
      }
    }

    if (selectedItemsData.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('productCatalogue')
            .doc(uniqueId)
            .set({
          'selectedItems': selectedItemsData,
          'timestamp': FieldValue.serverTimestamp(),
        });

        String shareUrl =
            'https://productcatelogue-61478.web.app/?code=$uniqueId';
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Share Collection'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(shareUrl),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _shareViaWhatsApp(shareUrl);
                    },
                    child: const Text('Share on Whatsapp...'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Items uploaded successfully')),
        );
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload items. Please try again.'),
          ),
        );
      }
    }
  }

  Future<String> _uploadImageToFirebase(String itemId, uniqueId) async {
    Reference storageReference = FirebaseStorage.instance
        .ref()
        .child('product_images')
        .child(uniqueId)
        .child('$itemId.jpg');
    UploadTask uploadTask = storageReference.putData(itemImages[itemId]!);
    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> _shareViaWhatsApp(String url) async {
    final whatsappUrl = "whatsapp://send?text=$url";
    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    } else {
      // Handle the case where WhatsApp is not installed
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("WhatsApp Not Installed"),
            content: const Text(
                "WhatsApp is not installed on your device. Please install WhatsApp to share."),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Style Check',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  setState(() {
                    isSelectionMode = !isSelectionMode;
                    selectedItems.clear(); // Clear selection on toggle
                  });
                },
                icon: Icon(Icons.select_all))
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Select Category',
                    style: TextStyle(fontSize: 25.sp),
                  ),
                  isLoadingCategories
                      ? CircularProgressIndicator()
                      : DropdownSearch<String>(
                          items: categories
                              .map((category) => category['name'] as String)
                              .toList(),
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: "Select Category",
                              hintText: "Search for a category",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          popupProps: PopupProps.bottomSheet(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 14),
                                hintText: "Search for categories...",
                              ),
                            ),
                          ),
                          onChanged: (String? value) {
                            if (value != null) {
                              final selectedCategory = categories.firstWhere(
                                  (category) => category['name'] == value);
                              setState(() {
                                selectedCategoryId =
                                    selectedCategory['category_id'].toString();
                              });
                              print(
                                  "Selected category ID: $selectedCategoryId");
                            }
                          },
                        ),
                  MaterialButton(
                    onPressed: () {
                      if (selectedCategoryId != null) {
                        getFilteredItems(selectedCategoryId!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select at least one category'),
                          ),
                        );
                      }
                    },
                    child: Text('Search'),
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  if (isSelectionMode)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (selectedItems.length == items.length) {
                            selectedItems.clear();
                          } else {
                            selectedItems = items
                                .map((item) => item['item_id'] as String)
                                .toSet();
                          }
                        });
                      },
                      child: Text(selectedItems.length == items.length
                          ? 'Deselect All'
                          : 'Select All'),
                    ),
                  isLoadingItems
                      ? CircularProgressIndicator()
                      : items.isNotEmpty
                          ? Column(
                              children: items.map((item) {
                                return Column(
                                  children: items.map((item) {
                                    bool isSelected =
                                        selectedItems.contains(item['item_id']);
                                    return GestureDetector(
                                      onTap: isSelectionMode
                                          ? () {
                                              setState(() {
                                                if (isSelected) {
                                                  selectedItems
                                                      .remove(item['item_id']);
                                                } else {
                                                  selectedItems
                                                      .add(item['item_id']);
                                                }
                                              });
                                            }
                                          : null,
                                      child: Container(
                                        margin: EdgeInsets.symmetric(
                                            vertical: 8.0, horizontal: 16.0),
                                        padding: EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.withOpacity(0.3)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8.0,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              child:
                                                  itemImages[item['item_id']] !=
                                                          null
                                                      ? Image.memory(
                                                          itemImages[
                                                              item['item_id']]!,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Container(
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              150, // Adjust height as needed
                                                          color: Colors.grey,
                                                          child: Icon(
                                                            Icons.image,
                                                            color: Colors.white,
                                                            size: 50,
                                                          ),
                                                        ),
                                            ),
                                            SizedBox(height: 5.h),
                                            Text(
                                              item['name'],
                                              style: TextStyle(
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              'Rate: ${item['rate']}',
                                              style: TextStyle(),
                                            ),
                                            if (isSelectionMode)
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (bool? value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      selectedItems
                                                          .add(item['item_id']);
                                                    } else {
                                                      selectedItems.remove(
                                                          item['item_id']);
                                                    }
                                                  });
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            )
                          : Text('No items found'),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: isSelectionMode
            ? FloatingActionButton(
                onPressed: _uploadSelectedItems,
                child: Icon(Icons.share),
              )
            : null);
  }
}
