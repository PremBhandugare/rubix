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
  String? _uploadedImageUrl;
  
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
    _uploadedImageUrl = await _uploadImage();

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
        'recipients':{
          'requests':[],
          'accepted':null
        },

      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Donation request submitted successfully!')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _image = null;
        expirationDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting donation: $e')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Donate Food')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Food Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                onSaved: (value) => foodName = value ?? '',
              ),
              SizedBox(height: 16),
              
              TextFormField(
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                onSaved: (value) => quantity = int.tryParse(value ?? '') ?? 0,
              ),
              SizedBox(height: 16),
              
              ListTile(
                title: Text('Expiration Date'),
                subtitle: Text(expirationDate?.toString() ?? 'Not selected'),
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
              ),
              
              DropdownButtonFormField<String>(
                value: foodCategory,
                decoration: InputDecoration(labelText: 'Food Category'),
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
              SizedBox(height: 16),
              
              TextFormField(
                decoration: InputDecoration(labelText: 'Contact Details'),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                onSaved: (value) => contactDetails = value ?? '',
              ),
              SizedBox(height: 16),
              
              ElevatedButton.icon(
                icon: Icon(Icons.photo_camera),
                label: Text('Add Photo'),
                onPressed: _pickImage,
              ),
              
              if (_image != null) ...[
                SizedBox(height: 8),
                Image.file(_image!, height: 200),
              ],
              
              SizedBox(height: 24),
              ElevatedButton(
                child: const Text('Submit Donation'),
                onPressed: _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}