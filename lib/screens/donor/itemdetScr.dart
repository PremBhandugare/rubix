import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemDisplayDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onPurchase;

  ItemDisplayDialog({required this.item, required this.onPurchase});

  @override
  _ItemDisplayDialogState createState() => _ItemDisplayDialogState();
}

class _ItemDisplayDialogState extends State<ItemDisplayDialog> {
  num _userPoints = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserPoints();
  }

  Future<void> _fetchUserPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('donors')
        .doc(user.uid)
        .get();

    setState(() {
      _userPoints = userDoc.data()?['points'] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  Widget contentBox(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Wallet icon with points
          Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  '$_userPoints',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: Colors.blue
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              widget.item['imageUrl'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 16),
          Text(
            widget.item['name'],
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            '${widget.item['price']} points',
            style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
          ),
          
          SizedBox(height: 16),
          Text(
            'Quantity ${widget.item['quantity']}',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
              ),
              ElevatedButton(
                onPressed: widget.item['price'] <= _userPoints 
                    ? widget.onPurchase 
                    : null,
                child:Text('Buy',style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.item['price'] <= _userPoints 
                      ? Colors.blue 
                      : Colors.grey,    
                ),
                
              ),
            ],
          ),
        ],
      ),
    );
  }
}