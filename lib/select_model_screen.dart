import 'package:flutter/material.dart';
import 'select_trim_screen.dart';

class SelectModelScreen extends StatefulWidget {
  final String brand;
  final bool isFromSignup;

  const SelectModelScreen({super.key, required this.brand, this.isFromSignup = false});

  @override
  State<SelectModelScreen> createState() => _SelectModelScreenState();
}

class _SelectModelScreenState extends State<SelectModelScreen> {
  // Car brand models
  final Map<String, List<String>> carBrandModels = {
    "BYD": ["Atto 3", "Seal", "Dolphin", "Han EV"],
    "Tesla": ["Model S", "Model 3", "Model X", "Model Y"],
    "Leapmotor": ["T03", "C11", "C01"],
    "Tata": ["Nexon EV", "Tiago EV", "Tigor EV"],
    "MG": ["ZS EV", "Comet EV"],
    "Hyundai": ["Kona Electric", "Ioniq 5", "Ioniq 6"],
    "Dongfeng": ["Fengshen E70", "Fengshen Yixuan EV"],
    "Nammi": ["EV1"],
    "Seres": ["SF5", "SF7"],
    "Jaecoo": ["J7", "J8"],
  };

  // Bike/Scooter brand models
  final Map<String, List<String>> bikeBrandModels = {
    "Ultraviolette": ["F77"],
    "NIU": ["NQi GT", "MQi+", "UQi GT"],
    "Ather": ["450X", "450 Plus"],
    "Segway": ["E110S", "E125S", "E300SE"],
    "Yatri": ["P-0", "P-1"],
    "Super Soco": ["TC Max", "CPx", "CUx"],
    "Komaki": ["X-One", "XGT X5", "MX3"],
    "Yadea": ["G5", "C1S", "KS5"],
  };

  @override
  Widget build(BuildContext context) {
    // Determine if the brand is a car or bike brand and get the appropriate models
    List<String> models = [];

    if (carBrandModels.containsKey(widget.brand)) {
      models = carBrandModels[widget.brand] ?? [];
    } else if (bikeBrandModels.containsKey(widget.brand)) {
      models = bikeBrandModels[widget.brand] ?? [];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Model"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header showing selected brand
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  widget.brand,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // List of models
          Expanded(
            child: ListView.separated(
              itemCount: models.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final model = models[index];
                return ListTile(
                  title: Text(model),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to trim selection
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectTrimScreen(
                          brand: widget.brand,
                          model: model,
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

// The SelectTrimScreen is now implemented in select_trim_screen.dart
