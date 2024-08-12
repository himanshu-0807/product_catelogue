import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:product_catelogue/MainScreen.dart';
import 'package:product_catelogue/add_product/add_product_form.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Login_screen.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Define the Item model
class Item {
  final String itemId;
  final String name;
  final String description;
  final double rate;
  final List<String> cfColor;
  final String categoryName;
  final String imageUrl;
  bool isSelected; // Add this line

  Item({
    required this.itemId,
    required this.name,
    required this.description,
    required this.rate,
    required this.cfColor,
    required this.categoryName,
    required this.imageUrl,
    this.isSelected = false, // Initialize isSelected to false
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    List<String> cfColorList =
        json['cf_color'] != null ? json['cf_color'].toString().split(" ") : [];

    return Item(
      itemId: json['item_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      cfColor: cfColorList,
      categoryName: json['category_name'] ?? '',
      imageUrl: "", // Adjust as per your actual JSON response
    );
  }
}

// Fetch the items from the API with pagination and retry mechanism
Future<List<Item>> getAllItems() async {
  List<Item> itemsList = [];
  int page = 1;
  int perPage = 200; // Maximum number of items per page
  int retryLimit = 3; // Maximum number of retries
  Duration retryDelay = Duration(seconds: 2); // Delay between retries

  try {
    String organizationId = '60026604390';
    String accessToken = await getAccssToken();

    Map<String, String> headers = {
      'Authorization': "Zoho-oauthtoken $accessToken"
    };

    bool moreItems = true;

    while (moreItems) {
      for (int retry = 0; retry < retryLimit; retry++) {
        try {
          final response = await http.get(
            Uri.parse(
                "https://www.zohoapis.in/books/v3/items?organization_id=$organizationId&page=$page&per_page=$perPage"),
            headers: headers,
          );

          if (response.statusCode == 200) {
            final decodedItems = jsonDecode(response.body);
            final items = decodedItems['items'] as List;
            for (var item in items) {
              try {
                itemsList.add(Item.fromJson(item));
              } catch (e) {
                print('Skipping item due to missing fields: ${e.toString()}');
              }
            }

            // Check if there are more items to fetch
            if (items.length < perPage) {
              moreItems = false;
            } else {
              page++;
            }
            break; // Break the retry loop on success
          } else {
            print('Error: ${response.statusCode}');
            moreItems = false;
            break; // Break the retry loop on non-retryable error
          }
        } catch (e) {
          print('Error: ${e.toString()}');
          if (retry == retryLimit - 1) {
            moreItems = false;
            break; // Break the retry loop after the last attempt
          }
          await Future.delayed(retryDelay); // Wait before retrying
        }
      }
    }
  } catch (e) {
    print('Error: ${e.toString()}');
  }

  return itemsList;
}

// Create the ListView in a StatefulWidget
class ItemsScreen extends StatefulWidget {
  @override
  _ItemsScreenState createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late Future<List<Item>> futureItems;
  List<Item> allItems = [];
  List<Item> filteredItems = [];
  TextEditingController searchController = TextEditingController();
  Map<String, bool> colorFilters = {
    'red': false,
    'blue': false,
    'green': false,
    'yellow': false,
    'black': false,
    'white': false,
  };

  List<String> categories = [];
  Map<String, bool> categoryFilters = {};
  bool isSelectionMode = false;
  bool isSelectAll = false;

  @override
  void initState() {
    super.initState();
    futureItems = getAllItems();
    futureItems.then((items) {
      setState(() {
        allItems = items;
        filteredItems = items;
      });
    });
    fetchAllCategories();
    searchController.addListener(_filterItems);
  }

  void _filterItems() {
    String query = searchController.text.toLowerCase();
    List<String> selectedColors = colorFilters.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    List<String> selectedCategories = categoryFilters.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    setState(() {
      filteredItems = allItems.where((item) {
        bool matchesQuery = item.name.toLowerCase().contains(query);
        bool matchesColor = selectedColors.isEmpty ||
            item.cfColor.any((color) => selectedColors.contains(color));
        bool matchesCategory = selectedCategories.isEmpty ||
            selectedCategories.contains(item.categoryName);
        return matchesQuery && matchesColor && matchesCategory;
      }).toList();
    });
  }

  Future<void> fetchAllCategories() async {
    String accessToken = await getAccssTokenForCategories();
    String orgId = "60026604390";
    Map<String, String> headers = {
      'Authorization': 'Zoho-oauthtoken $accessToken',
      'X-com-zoho-store-organizationid': orgId
    };
    try {
      final response = await http.get(
          Uri.parse('https://commerce.zoho.in/store/api/v1/categories'),
          headers: headers);

      if (response.statusCode == 200) {
        print(response.body);
        final data = jsonDecode(response.body);
        final categoriesData = data['categories'];
        List<String> fetchedCategories = [];
        for (var category in categoriesData) {
          fetchedCategories.add(category['name']);
        }
        setState(() {
          categories = fetchedCategories;
          categoryFilters = {for (var category in categories) category: false};
        });
      } else {
        print(response.statusCode);
      }
    } catch (e) {
      print(e.toString());
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Filter by Color',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 10.0,
                    children: colorFilters.keys.map((color) {
                      return FilterChip(
                        label: Text(color),
                        selected: colorFilters[color]!,
                        onSelected: (bool selected) {
                          setModalState(() {
                            colorFilters[color] = selected;
                          });
                          _filterItems();
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                  Text('Filter by Category',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 10.0,
                    children: categories.map((category) {
                      return FilterChip(
                        label: Text(category),
                        selected: categoryFilters[category]!,
                        onSelected: (bool selected) {
                          setModalState(() {
                            categoryFilters[category] = selected;
                          });
                          _filterItems();
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      isSelectAll = value ?? false;
      filteredItems.forEach((item) {
        item.isSelected = isSelectAll;
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool isAnyItemSelected() {
    return filteredItems.any((item) => item.isSelected);
  }

  String _generateUniqueId() {
    var rng = Random();
    var code = (rng.nextDouble() * 900000).toInt() + 100000;
    return code.toString();
  }

  void _uploadSelectedItems() async {
    // Get selected items
    List<Item> selectedItems =
        filteredItems.where((item) => item.isSelected).toList();

    // Show dialog to input collection name
    String? collectionName = await _showCollectionNameDialog();

    if (collectionName != null &&
        collectionName.isNotEmpty &&
        selectedItems.isNotEmpty) {
      // Generate unique 6-digit document ID
      String uniqueId = _generateUniqueId();

      // Extract required fields for selected items
      List<Map<String, dynamic>> selectedItemsData = selectedItems
          .map((item) => {
                'itemId': item.itemId,
                'name': item.name,
                'cfColor': item.cfColor,
                'categoryName': item.categoryName,
                'rate': item.rate,
                'description': item.description
              })
          .toList();

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing dialog
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

      // Upload to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('productCatalogue')
            .doc(uniqueId)
            .set({
          'collectionName': collectionName,
          'selectedItems': selectedItemsData,
          'timestamp': FieldValue.serverTimestamp(),
        });

        String shareUrl =
            'https://productcatelogue-61478.web.app/?code=$uniqueId';
        Navigator.pop(context); // Close the loading dialog

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
                      _launchUrl(shareUrl);
                    },
                    child: const Text('Share via...'),
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
        print('Share this URL: $shareUrl');
        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Items uploaded successfully')),
        );
      } catch (e) {
        print('Error uploading items: $e');
        Navigator.pop(context); // Close the loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload items. Please try again.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Please select items and provide a collection name.')),
      );
    }
  }

  Future<void> _launchUrl(String link) async {
    final Uri _url = Uri.parse(link);

    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<String?> _showCollectionNameDialog() async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Collection Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter collection name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Items List'),
        actions: [
          if (isSelectionMode)
            Checkbox(
              value: isSelectAll,
              onChanged: _toggleSelectAll,
            ),
          if (!isSelectionMode)
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: _showFilterModal,
            ),
          IconButton(
            icon: Icon(isSelectionMode ? Icons.cancel : Icons.select_all),
            onPressed: () {
              setState(() {
                isSelectionMode = !isSelectionMode;
                if (!isSelectionMode) {
                  filteredItems.forEach((item) {
                    item.isSelected = false;
                  });
                  isSelectAll = false;
                }
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: futureItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No items found'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              Text(
                'Showing ${filteredItems.length} of ${allItems.length} products',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailsScreen(item: item)));
                      },
                      leading: isSelectionMode
                          ? Checkbox(
                              value: item.isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  item.isSelected = value ?? false;
                                  if (!item.isSelected) {
                                    isSelectAll = false;
                                  }
                                });
                              },
                            )
                          : null,
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Description: ${item.description}'),
                          Text('Rate: ${item.rate}'),
                          Text('Colors: ${item.cfColor.join(', ')}'),
                          Text('Category: ${item.categoryName}'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isAnyItemSelected()
          ? FloatingActionButton(
              onPressed: _uploadSelectedItems,
              child: Icon(Icons.share),
            )
          : null,
    );
  }
}

Future<String> getAccssToken() async {
  String refresh_token =
      '1000.34c3d54b32bbb12bc6ed06f97ce46669.98fbcf408998cf5348b3c01d6d7e4e9d';
  String client_id = '1000.8D1CXTZ1XTCJOLZ5SNR25Z9ULKYKCC';
  String client_secret = '07eda3e97bdbf586e973657f1c58bb8d9214d64d8f';
  String redirect_uri = 'https://divinzo.com/';

  try {
    final response = await http.post(
      Uri.parse('https://accounts.zoho.in/oauth/v2/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'refresh_token': refresh_token,
        'client_id': client_id,
        'client_secret': client_secret,
        'redirect_uri': redirect_uri,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = json.decode(response.body);
      return responseData['access_token'];
    } else {
      throw Exception(
          'Failed to retrieve access token. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
    throw Exception('Failed to retrieve access token.');
  }
}

Future<String> getAccssTokenForCategories() async {
  String refresh_token =
      '1000.84b9d475116a5f047f4b5ac506544dfd.9ade7f2cfb77d5123df1df784befbe47';
  String client_id = '1000.8D1CXTZ1XTCJOLZ5SNR25Z9ULKYKCC';
  String client_secret = '07eda3e97bdbf586e973657f1c58bb8d9214d64d8f';
  String redirect_uri = 'https://divinzo.com/';

  try {
    final response = await http.post(
      Uri.parse('https://accounts.zoho.in/oauth/v2/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'refresh_token': refresh_token,
        'client_id': client_id,
        'client_secret': client_secret,
        'redirect_uri': redirect_uri,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = json.decode(response.body);
      print('Access token of cat = ${responseData['access_token']}');
      return responseData['access_token'];
    } else {
      throw Exception(
          'Failed to retrieve access token. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
    throw Exception('Failed to retrieve access token.');
  }
}

class ProductDetailsScreen extends StatelessWidget {
  final Item item;

  ProductDetailsScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(item.description),
            SizedBox(height: 16),
            Text(
              'Rate:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Rs. ${item.rate.toStringAsFixed(2)}'),
            SizedBox(height: 16),
            Text(
              'Category:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(item.categoryName),
            SizedBox(height: 16),
            Text(
              'Colors:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: item.cfColor
                  .map((color) => Chip(label: Text(color)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //Set the fit size (Find your UI design, look at the dimensions of the device screen and fill it in,unit in dp)
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      // Use builder only if you need to use library outside ScreenUtilInit context
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Style Check',
          // You can use the library anywhere in the app even in theme

          home: child,
        );
      },
      child: Mainscreen(),
    );
  }
}
