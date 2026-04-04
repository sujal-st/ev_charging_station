import 'package:flutter/material.dart';
import 'select_model_screen.dart';

class SelectBrandScreen extends StatefulWidget {
  final String vehicleType;
  final bool isFromSignup;

  const SelectBrandScreen({super.key, required this.vehicleType, this.isFromSignup = false});

  @override
  State<SelectBrandScreen> createState() => _SelectBrandScreenState();
}

class _SelectBrandScreenState extends State<SelectBrandScreen> {
  // Car brands
  final List<String> carBrands = [
    "BYD",
    "Tesla",
    "Leapmotor",
    "Tata",
    "MG",
    "Hyundai",
    "Dongfeng",
    "Nammi",
    "Seres",
    "Jaecoo",
  ];

  // Bike/Scooter brands
  final List<String> bikeBrands = [
    "Ultraviolette",
    "NIU",
    "Ather",
    "Segway",
    "Yatri",
    "Super Soco",
    "Komaki",
    "Yadea",
  ];

  String searchText = "";

  @override
  Widget build(BuildContext context) {
    // Get the appropriate brand list based on vehicle type
    final List<String> brands =
        widget.vehicleType == 'car' ? carBrands : bikeBrands;

    final filteredBrands = brands
        .where((b) => b.toLowerCase().contains(searchText.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Select ${widget.vehicleType == 'car' ? 'Car' : 'Bike/Scooter'} Brand"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filteredBrands.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final brand = filteredBrands[index];
                return ListTile(
                  title: Text(brand),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectModelScreen(
                          brand: brand,
                          isFromSignup: widget.isFromSignup,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
