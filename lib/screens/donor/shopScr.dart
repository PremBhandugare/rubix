import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rubix/data/shopitems.dart';
import 'package:rubix/screens/donor/itemdetScr.dart';

class DonationShopScreen extends StatefulWidget {
  @override
  _DonationShopScreenState createState() => _DonationShopScreenState();
}

class _DonationShopScreenState extends State<DonationShopScreen> {
num? _points;
@override
void initState() {
  super.initState();
  _loadUserPoints();
}
Future<num> _fetchUserPoints() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0;

  final userDoc = await FirebaseFirestore.instance
      .collection('donors')
      .doc(user.uid)
      .get();

  return userDoc.data()?['points'] ?? 0;
}
void _loadUserPoints() async {
  final points = await _fetchUserPoints();
  setState(() {
    _points = points;
  });
}

  void _purchaseFood(Map<String, dynamic> food) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Fetch current points
  num currentPoints = await _fetchUserPoints();

  if (currentPoints >= food['price']) {
    // Deduct points from database
    await FirebaseFirestore.instance
        .collection('donors')
        .doc(user.uid)
        .update({
      'points': FieldValue.increment(-food['price'])
    });

    // Add the purchased item to the 'purchases' collection
    await FirebaseFirestore.instance.collection('purchases').add({
      'userId': user.uid,
      'foodName': food['name'],
      'foodCategory': food['category'],
      'imageUrl': food['imageUrl'],
      'quantity': food['quantity'],
      'timestamp': FieldValue.serverTimestamp(),
      'donated': false,
    });

    // Update local state to reflect new points
    setState(() {
      _points = currentPoints - food['price'];
    });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Insufficient points.')),
    );
  }
}

  List<Map<String, dynamic>> _filterItemsByCategory(String category) {
    return donationShopItems.where((item) => item['category'] == category).toList();
  }

   void _showItemDisplay(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ItemDisplayDialog(
          item: item,
          onPurchase: () {
            _purchaseFood(item);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['Canned', 'Fresh', 'Packaged', 'Cooked'];

    return Scaffold(   
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          if (index == 0) {
        // First item: Hero Section
        return Center(
          child: Column(
            children: [
              SizedBox(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 30,),
                  Image.asset(
                    'assets/globe.png',
                    height: 30,
                    width: 30,
                  ),
                  const SizedBox(width: 10,),
                  Text(
                    'Ahar Setu',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildHeroSection(),
              SizedBox(height: 10),
            ],
          ),
        );
      }
          final category = categories[index];
          final items = _filterItemsByCategory(category);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    itemBuilder: (context, itemIndex) {
                      final item = items[itemIndex];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _DonationShopItemTile(
                          item: item,
                          onTap: () => _showItemDisplay(context, item),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DonationShopItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  _DonationShopItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['imageUrl'],
                height: 160,
                width: 160,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 8),
            Text(
              item['name'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              '${item['price']} points',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
Widget _buildHeroSection() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/Hero1.jpg',
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 5,
                left: 5,
                right: 5,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Support those in need',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
