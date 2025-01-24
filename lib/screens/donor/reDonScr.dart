import 'dart:convert';
import 'package:http/http.dart' as http;
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
  String address = ''; // New field for address
  GeoPoint? locationCoordinates;
  double? latitude;
  double? longitude;

 Future<void> _convertAddressToCoordinates() async {
  if (address.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please enter a valid address'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  const apiKey = 'oyLqwKTDuilIERXSgG5B'; // Your MapTiler API key
  final encodedAddress = Uri.encodeComponent(address);
  final url = 'https://api.maptiler.com/geocoding/$encodedAddress.json?key=$apiKey';

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'].isNotEmpty) {
        final coordinates = data['features'][0]['center'];
        setState(() {
          locationCoordinates = GeoPoint(coordinates[1], coordinates[0]);
          latitude = coordinates[1];
          longitude = coordinates[0];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to find coordinates'),
            backgroundColor: Colors.orange,
          ),
        );
        locationCoordinates = null;
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Geocoding error: $e'),
        backgroundColor: Colors.red,
      ),
    );
    locationCoordinates = null;
  }
}

  
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

      // Convert address to coordinates before submission
    await _convertAddressToCoordinates();

    // Only proceed if coordinates were successfully obtained
    if (locationCoordinates == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to process location. Please check your address.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      

     // Upload image if selected
    String? imageUrl = _image != null 
        ? await _uploadImage() 
        : _uploadedImageUrl;

      try {
        // Get the current user's ID
        final String? userId = FirebaseAuth.instance.currentUser?.uid;
        
        // Prepare donation data
        var donationData = {
          'userId': userId, // Store user ID
          'foodName': foodName,
          'quantity': quantity,
          'expirationDate': Timestamp.fromDate(expirationDate!),
          'foodCategory': foodCategory,
          'contactDetails': contactDetails,
          'imageUrl': imageUrl,
          'address': address, // Store raw address
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'status': "available",
          'recipients': {
            'requests': [],
            'accepted': null
          },
        };

        // Create donation document
        await firestore.collection('donations').add(donationData);

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
          address = '';
          locationCoordinates = null;
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
                // New Card for Address
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Full Address',
                            hintText: 'Enter complete pickup address',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          maxLines: 2,
                          validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
                          onSaved: (value) => address = value ?? '',
                        ),
                        SizedBox(height: 8),
                        if (locationCoordinates != null)
                          Text(
                            'Coordinates: ${locationCoordinates!.latitude}, ${locationCoordinates!.longitude}',
                            style: TextStyle(color: Colors.green),
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

