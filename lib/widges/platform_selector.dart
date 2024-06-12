import 'package:auto_report/data/proto/response/get_platforms_response.dart';
import 'package:flutter/material.dart';

class PlatformSelector extends StatefulWidget {
  const PlatformSelector({super.key, required this.platforms});

  final List<GetPlatformsResponseData?>? platforms;

  @override
  State<PlatformSelector> createState() => _PlatformSelectorState();
}

class _PlatformSelectorState extends State<PlatformSelector> {
  late String? dropdownValue;

  @override
  void initState() {
    super.initState();
    dropdownValue = widget.platforms?.first?.name;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      initialSelection: dropdownValue,
      onSelected: (String? value) {
        setState(() {
          dropdownValue = value!;
        });
      },
      dropdownMenuEntries:
          widget.platforms?.map<DropdownMenuEntry<String>>((value) {
                final name = value?.name ?? '';
                return DropdownMenuEntry<String>(value: name, label: name);
              }).toList() ??
              [],
    );
  }
}
