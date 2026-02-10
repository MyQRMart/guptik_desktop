import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/board.dart';
import '../utils/wifi_service.dart';

// Add Home Dialog
class AddHomeDialog extends StatefulWidget {
  final Function(Home) onHomeAdded;

  const AddHomeDialog({
    required this.onHomeAdded,
    super.key,
  });

  @override
  State<AddHomeDialog> createState() => _AddHomeDialogState();
}

class _AddHomeDialogState extends State<AddHomeDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home name is required')),
      );
      return;
    }

    final home = Home(
      name: _nameController.text,
      address: _addressController.text.isNotEmpty ? _addressController.text : null,
      city: _cityController.text.isNotEmpty ? _cityController.text : null,
      userId: '', // Will be set by parent
    );

    widget.onHomeAdded(home);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Add New Home',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField('Home Name', _nameController, 'e.g., My Home'),
          const SizedBox(height: 12),
          _buildTextField('Address', _addressController, 'Optional'),
          const SizedBox(height: 12),
          _buildTextField('City', _cityController, 'Optional'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Add Home'),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

// Add Room Dialog
class AddRoomDialog extends StatefulWidget {
  final Function(Room) onRoomAdded;
  final String homeId;

  const AddRoomDialog({
    required this.onRoomAdded,
    required this.homeId,
    super.key,
  });

  @override
  State<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<AddRoomDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = 'meeting_room';

  final _iconOptions = [
    ('meeting_room', '🏠 Meeting Room'),
    ('bedroom', '🛏️ Bedroom'),
    ('kitchen', '🍳 Kitchen'),
    ('living_room', '🛋️ Living Room'),
    ('bathroom', '🚿 Bathroom'),
    ('office', '🖥️ Office'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room name is required')),
      );
      return;
    }

    final room = Room(
      homeId: widget.homeId,
      name: _nameController.text,
      icon: _selectedIcon,
      displayOrder: 0,
    );

    widget.onRoomAdded(room);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Add New Room',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Name',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Living Room',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Room Type',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _iconOptions.map((option) {
              final isSelected = _selectedIcon == option.$1;
              return ChoiceChip(
                label: Text(option.$2),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedIcon = option.$1);
                },
                backgroundColor: Colors.white.withOpacity(0.05),
                selectedColor: Colors.cyanAccent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Add Room'),
        ),
      ],
    );
  }
}

// Add Board Dialog
class AddBoardDialog extends StatefulWidget {
  final Function(Board) onBoardAdded;
  final String? homeId;
  final String? roomId;

  const AddBoardDialog({
    required this.onBoardAdded,
    this.homeId,
    this.roomId,
    super.key,
  });

  @override
  State<AddBoardDialog> createState() => _AddBoardDialogState();
}

class _AddBoardDialogState extends State<AddBoardDialog> {
  final _nameController = TextEditingController();
  final _macController = TextEditingController();
  String _selectedNetwork = '';
  List<String> _availableNetworks = [];
  bool _isLoadingNetworks = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    try {
      final networks = await WifiService.getAvailableNetworks();
      setState(() {
        _availableNetworks = networks;
        if (networks.isNotEmpty) {
          _selectedNetwork = networks[0];
        }
        _isLoadingNetworks = false;
      });
    } catch (e) {
      setState(() => _isLoadingNetworks = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _macController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _selectedNetwork.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board name and network are required')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      // Connect to network
      final connected = await WifiService.connectToNetwork(_selectedNetwork, '');
      
      if (connected) {
        final board = Board(
          homeId: widget.homeId,
          roomId: widget.roomId,
          ownerId: '', // Will be set by parent
          name: _nameController.text,
          macAddress: _macController.text.isNotEmpty ? _macController.text : null,
          status: 'online',
        );

        widget.onBoardAdded(board);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to network'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Add New Board/Controller',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Board Name',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Main Board',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'MAC Address (Optional)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _macController,
              decoration: InputDecoration(
                hintText: 'e.g., 00:1A:2B:3C:4D:5E',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select GupTikSmart Network',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isLoadingNetworks)
              const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              )
            else if (_availableNetworks.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: const Text(
                  'No GupTikSmart networks found. Please ensure your board is powered on.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            else
              Column(
                children: _availableNetworks.map((network) {
                  return RadioListTile(
                    title: Text(
                      network,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: network,
                    groupValue: _selectedNetwork,
                    onChanged: (value) {
                      setState(() => _selectedNetwork = value ?? '');
                    },
                    activeColor: Colors.cyanAccent,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          child: _isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text('Add Board'),
        ),
      ],
    );
  }
}
