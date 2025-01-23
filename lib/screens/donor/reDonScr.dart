import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DonationRequestScreen extends StatefulWidget {
  const DonationRequestScreen({super.key});

  @override
  _DonationRequestScreenState createState() => _DonationRequestScreenState();
}

class _DonationRequestScreenState extends State<DonationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final firestore = FirebaseFirestore.instance;
  File? _image;
  String _uploadedImageUrl= 'https://st5.depositphotos.com/23188010/77700/i/450/depositphotos_777000678-stock-photo-food-icons-set-vector-illustration.jpg';
  
  String foodName = '';
  int quantity = 0;
  DateTime? expirationDate;
  String foodCategory = 'Fresh';
  String contactDetails = '';
  
  final List<String> categories = ['Fresh', 'Cooked', 'Canned', 'Packaged'];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;
    
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('donation_images')
          .child('${DateTime.now().toIso8601String()}.jpg');
          
      await ref.putFile(_image!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Upload image if selected
      setState(() async {
        _uploadedImageUrl = (await _uploadImage())!;
      });

      try {
        // Get the current user's ID
        final String? userId = FirebaseAuth.instance.currentUser?.uid;
        

        // Create donation document
        await firestore.collection('donations').add({
          'userId': userId, // Store user ID
          'foodName': foodName,
          'quantity': quantity,
          'expirationDate': Timestamp.fromDate(expirationDate!),
          'foodCategory': foodCategory,
          'contactDetails': contactDetails,
          'imageUrl': _uploadedImageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'status': "available",
          'recipients': {
            'requests': [],
            'accepted': null
          },
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _image = null;
          expirationDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting donation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Donate Food'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Food Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.fastfood),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          onSaved: (value) => foodName = value ?? '',
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_basket),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          onSaved: (value) => quantity = int.tryParse(value ?? '') ?? 0,
                        ),
                        SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => expirationDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Expiration Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              expirationDate?.toString().split(' ')[0] ?? 'Select Date',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: foodCategory,
                          decoration: InputDecoration(
                            labelText: 'Food Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => foodCategory = value ?? 'Fresh');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Contact Details',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.contact_phone),
                          ),
                          maxLines: 1,
                          keyboardType: TextInputType.phone,
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          onSaved: (value) => contactDetails = value ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Image',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: _image == null
                              ? Icon(Icons.add_a_photo, size: 100, color: Colors.grey)
                              : Image.file(_image!, height: 200),
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.photo_camera),
                            label: Text('Add Photo'),
                            onPressed: _pickImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 239, 239, 239),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Submit Donation',
                      style: TextStyle(color: Colors.white,fontSize: 18),
                    ),
                  ),
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

