import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class PurchasesScreen extends StatefulWidget {
  @override
  _PurchasesScreenState createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _contactController = TextEditingController();
  DateTime? _selectedExpiryDate;

  void _showDonationDialog(DocumentSnapshot purchase) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                'Donate Food Item', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: Colors.green[700]
                ),
                textAlign: TextAlign.center,
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length != 10) {
                          return 'Please enter a 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        
                        if (pickedDate != null) {
                          setState(() {
                            _selectedExpiryDate = pickedDate;
                          });
                        }
                      },
                      icon: Icon(Icons.calendar_today),
                      label: Text(
                        _selectedExpiryDate == null 
                          ? 'Select Expiry Date' 
                          : 'Expiry: ${DateFormat('dd/MM/yyyy').format(_selectedExpiryDate!)}',
                        style: TextStyle(
                          color: _selectedExpiryDate == null 
                            ? Colors.grey 
                            : Colors.black
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate() && _selectedExpiryDate != null) {
                      try {
                        await _submitDonation(purchase);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Donation submitted successfully!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to submit donation: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Donate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitDonation(DocumentSnapshot purchase) async {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    await firestore.collection('donations').add({
      'userId': userId,
      'foodName': purchase['foodName'],
      'quantity': purchase['quantity'] ?? 1,
      'expirationDate': Timestamp.fromDate(_selectedExpiryDate!),
      'foodCategory': purchase['foodCategory'],
      'contactDetails': _contactController.text,
      'imageUrl': purchase['imageUrl'],
      'timestamp': FieldValue.serverTimestamp(),
      'status': "available",
      'recipients': {
        'requests': [],
        'accepted': null
      },
    });

    // Mark the purchase as donated
    await purchase.reference.update({'donated': true});
  }

  // Rest of the build method remains the same as in the previous version
  @override
  Widget build(BuildContext context) {
    // Previous build method content
    return Scaffold(
      appBar: AppBar(
        title: Text('My Purchases'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('purchases')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No purchases yet',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var purchase = snapshot.data!.docs[index];
              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: purchase['imageUrl'] != null
                        ? Image.network(
                            purchase['imageUrl'],
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          )
                        : Icon(Icons.fastfood, size: 70),
                  ),
                  title: Text(
                    purchase['foodName'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category: ${purchase['foodCategory']}'),
                      Text(
                        'Purchased: ${DateFormat('dd/MM/yyyy HH:mm').format(purchase['timestamp'].toDate())}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: purchase['donated'] != true 
                    ? ElevatedButton(
                        onPressed: () => _showDonationDialog(purchase),
                        child: Text('Donate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      )
                    : Text(
                        'Donated',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}