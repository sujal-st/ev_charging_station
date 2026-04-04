import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'models/booking_model.dart';
import 'NavigationScreen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'package:latlong2/latlong.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int selectedTab = 0; // 0 = Upcoming, 1 = Completed, 2 = Cancelled

  @override
  void initState() {
    super.initState();
    // Schedule loading after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  void _loadBookings() {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      bookingProvider.loadUserBookings(authProvider.currentUser!.uid);
    } else {
      // Clear any existing bookings if user is not authenticated
      bookingProvider.clearBookings();
    }
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    final success = await bookingProvider.cancelBooking(
      booking.id, 
      authProvider.currentUser!.uid
    );
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking Cancelled"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingProvider.error ?? "Failed to cancel booking"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewBooking(BookingModel booking) {
    // Navigate to booking details or navigation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          start: LatLng(27.7172, 85.3240), // Current location - you might want to get real location
          end: LatLng(booking.stationLatitude, booking.stationLongitude),
          routePoints: [], // You might want to calculate route here
        ),
      ),
    );
  }

  Future<void> _toggleReminder(BookingModel booking, bool remindMe) async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    await bookingProvider.updateBookingReminder(
      booking.id, 
      remindMe, 
      authProvider.currentUser!.uid
    );
  }

  Widget buildBookingCard(BookingModel booking) {
    String extraText = "";
    bool disableButtons = false;
    
    switch (booking.status) {
      case "completed":
        extraText = "✅ Charging completed successfully.";
        disableButtons = true;
        break;
      case "cancelled":
        extraText = "❌ This booking was cancelled.";
        disableButtons = true;
        break;
      case "in_progress":
        extraText = "🔋 Charging in progress...";
        disableButtons = true;
        break;
    }
    
    return bookingCard(
      booking: booking,
      extraText: extraText,
      disableButtons: disableButtons,
    );
  }

  Widget bookingCard({
    required BookingModel booking,
    String extraText = "", 
    bool disableButtons = false
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Reminder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${booking.formattedDate}\n${booking.formattedTime}",
                style: const TextStyle(fontWeight: FontWeight.w500)
              ),
              if (!disableButtons)
                Row(
                  children: [
                    const Text("Remind me"),
                    Switch(
                      value: booking.remindMe,
                      activeThumbColor: Colors.green,
                      onChanged: (val) {
                        _toggleReminder(booking, val);
                      },
                    )
                  ],
                )
            ],
          ),
          const SizedBox(height: 8),

          // Station Name + Direction Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.stationName,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    Text(
                      booking.stationAddress, 
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _viewBooking(booking),
                child: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.navigation, color: Colors.white),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Booking Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const Icon(Icons.ev_station),
                  const SizedBox(height: 4),
                  Text(booking.plugType),
                ],
              ),
              Column(
                children: [
                  Text(
                    "${booking.maxPower.toInt()} kW", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const Text("Max power"),
                ],
              ),
              Column(
                children: [
                  Text(
                    booking.formattedDuration, 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const Text("Duration"),
                ],
              ),
              Column(
                children: [
                  Text(
                    booking.formattedAmount,
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const Text("Amount"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Buttons
          if (!disableButtons)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelBooking(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Cancel Booking"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _viewBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("View"),
                  ),
                ),
                const SizedBox(width: 12),
                // Future Payment button placeholder for upcoming bookings
                if (booking.isUpcoming)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment coming soon'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Pay"),
                    ),
                  ),
              ],
            ),
          if (extraText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              extraText,
              style: TextStyle(
                color: disableButtons ? Colors.red : Colors.green
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Info Box
          if (!disableButtons)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Insert the charger connection into your car to start charging. "
                      "If you do not charge after 15 minutes from the time, this booking will be automatically cancelled.",
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, BookingProvider>(
      builder: (context, authProvider, bookingProvider, child) {
        // Check if user is logged in
        if (authProvider.currentUser == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.green),
              title: const Text('My Bookings', style: TextStyle(color: Colors.green)),
            ),
            body: const Center(
              child: Text('Please log in to view your bookings'),
            ),
          );
        }

        // Get bookings based on selected tab
        List<BookingModel> bookings = [];
        switch (selectedTab) {
          case 0:
            bookings = bookingProvider.upcomingBookings;
            break;
          case 1:
            bookings = bookingProvider.completedBookings;
            break;
          case 2:
            bookings = bookingProvider.cancelledBookings;
            break;
        }

        return Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 2,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            onTap: (index) {
              switch (index) {
                case 0:
                  // Navigate to Home
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                  break;
                case 1:
                  // Navigate to Favorites
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesScreen(),
                    ),
                  );
                  break;
                case 2:
                  // Already on My Bookings screen
                  break;
                case 3:
                  // Navigate to Profile
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  break;
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border), label: "Favorites"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_turned_in), label: "My bookings"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.green),
            title: const Text('My Bookings', style: TextStyle(color: Colors.green)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadBookings(),
              ),
            ],
          ),
          body: bookingProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : bookingProvider.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            bookingProvider.error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadBookings(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Tabs
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedTab = 0),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Upcoming (${bookingProvider.upcomingBookings.length})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedTab == 0
                                              ? Colors.green
                                              : Colors.grey
                                        ),
                                      ),
                                      if (selectedTab == 0)
                                        Container(
                                          height: 2,
                                          color: Colors.green,
                                          margin: const EdgeInsets.only(top: 4)
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedTab = 1),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Completed (${bookingProvider.completedBookings.length})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedTab == 1
                                              ? Colors.green
                                              : Colors.grey
                                        ),
                                      ),
                                      if (selectedTab == 1)
                                        Container(
                                          height: 2,
                                          color: Colors.green,
                                          margin: const EdgeInsets.only(top: 4)
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedTab = 2),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Cancelled (${bookingProvider.cancelledBookings.length})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedTab == 2
                                              ? Colors.green
                                              : Colors.grey
                                        ),
                                      ),
                                      if (selectedTab == 2)
                                        Container(
                                          height: 2,
                                          color: Colors.green,
                                          margin: const EdgeInsets.only(top: 4)
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Content based on selected tab
                          Expanded(
                            child: bookings.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          selectedTab == 0
                                              ? Icons.schedule
                                              : selectedTab == 1
                                                  ? Icons.check_circle_outline
                                                  : Icons.cancel_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          selectedTab == 0
                                              ? 'No upcoming bookings'
                                              : selectedTab == 1
                                                  ? 'No completed bookings'
                                                  : 'No cancelled bookings',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: bookings.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: buildBookingCard(bookings[index]),
                                      );
                                    },
                                  ),
                          )
                        ],
                      ),
                    ),
        );
      },
    );
  }
}
