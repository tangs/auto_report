import 'package:auto_report/banks/wave/data/proto/response/get_platforms_response.dart';
import 'package:flutter/material.dart';

typedef OnPlatformSelectorValueChangedCallback = void Function(
    GetPlatformsResponseData? platform);

class PlatformSelector extends StatefulWidget {
  const PlatformSelector({
    super.key,
    required this.platforms,
    required this.onValueChangedCallback,
  });

  final List<GetPlatformsResponseData?>? platforms;
  final OnPlatformSelectorValueChangedCallback? onValueChangedCallback;

  @override
  State<PlatformSelector> createState() => _PlatformSelectorState();
}

class _PlatformSelectorState extends State<PlatformSelector> {
  late GetPlatformsResponseData? dropdownValue;

  @override
  void initState() {
    super.initState();
    dropdownValue = widget.platforms?.first;
    widget.onValueChangedCallback?.call(dropdownValue);
  }

  @override
  Widget build(BuildContext context) {
    final platforms = widget.platforms;
    return DropdownMenu<GetPlatformsResponseData?>(
      initialSelection: dropdownValue,
      onSelected: (GetPlatformsResponseData? value) {
        setState(() {
          dropdownValue = value;
          widget.onValueChangedCallback?.call(dropdownValue);
        });
      },
      dropdownMenuEntries:
          platforms?.map<DropdownMenuEntry<GetPlatformsResponseData?>>((value) {
                final name = value?.name ?? '';
                return DropdownMenuEntry<GetPlatformsResponseData?>(
                    value: value, label: name);
              }).toList() ??
              [],
    );
  }
}
