import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:product_catelogue/add_product/add_product_form.dart';
import 'package:product_catelogue/product_catelogue/home_screen.dart';

class Mainscreen extends StatelessWidget {
  const Mainscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Style Check',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => HomeScreen()));
                },
                child: Container(
                  height: 100.h,
                  color: Colors.blue,
                  child: Center(child: Text('Product Catelogue')),
                ),
              ),
            ),
            SizedBox(
              width: 5.h,
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AddProductForm()));
                },
                child: Container(
                  height: 100.h,
                  color: Colors.blue,
                  child: Center(child: Text('Add New Product')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
