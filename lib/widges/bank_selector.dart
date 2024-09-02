import 'package:flutter/material.dart';

typedef OnBankSelectorValueChangedCallback = void Function(BankType bank);

enum BankType {
  wave,
  kbz,
  kbiz;

  String get value => toString().split(".").last;
}

class BankSelector extends StatefulWidget {
  BankSelector({
    super.key,
    required this.onValueChangedCallback,
  });

  final List<BankType> banks = BankType.values.toList();
  final OnBankSelectorValueChangedCallback? onValueChangedCallback;

  @override
  State<BankSelector> createState() => _BankSelectorState();
}

class _BankSelectorState extends State<BankSelector> {
  late BankType dropdownValue;

  @override
  void initState() {
    super.initState();
    dropdownValue = widget.banks.last;
    widget.onValueChangedCallback?.call(dropdownValue);
  }

  @override
  Widget build(BuildContext context) {
    final banks = widget.banks;
    return DropdownMenu<BankType>(
      initialSelection: dropdownValue,
      onSelected: (BankType? value) {
        setState(() {
          dropdownValue = value ?? BankType.kbz;
          widget.onValueChangedCallback?.call(dropdownValue);
        });
      },
      dropdownMenuEntries: banks.map<DropdownMenuEntry<BankType>>((value) {
        final name = value.toString().split('.').last;
        return DropdownMenuEntry<BankType>(value: value, label: name);
      }).toList(),
    );
  }
}
