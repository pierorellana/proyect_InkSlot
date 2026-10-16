import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../domain/booking_request_status.dart';

class ContactChannelField extends StatelessWidget {
  const ContactChannelField({
    required this.channel,
    required this.controller,
    required this.onChannelChanged,
    super.key,
    this.enabled = true,
  });

  final ContactChannel channel;
  final TextEditingController controller;
  final ValueChanged<ContactChannel> onChannelChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<ContactChannel>(
        initialValue: channel,
        isExpanded: true,
        decoration: _decoration('Canal de contacto'),
        items: ContactChannel.values
            .map(
              (value) => DropdownMenuItem<ContactChannel>(
                value: value,
                child: Text(value.label),
              ),
            )
            .toList(growable: false),
        onChanged: enabled
            ? (value) {
                if (value != null) onChannelChanged(value);
              }
            : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: channel.keyboardType,
        textInputAction: TextInputAction.next,
        maxLength: channel == ContactChannel.instagram ? 64 : 32,
        validator: (value) => _validateContact(channel, value),
        decoration: _decoration(
          channel.valueLabel,
          hintText: channel.hint,
          prefixIcon: Icon(channel.icon, size: 20),
          counterText: '',
        ),
      ),
    ],
  );

  String? _validateContact(ContactChannel channel, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ingresa un dato de contacto.';
    if (channel == ContactChannel.email &&
        (!text.contains('@') || !text.contains('.'))) {
      return 'Revisa el formato del correo.';
    }
    if (channel == ContactChannel.instagram && text.length > 64) {
      return 'Usa máximo 64 caracteres.';
    }
    if (channel != ContactChannel.instagram && text.length > 32) {
      return 'Usa máximo 32 caracteres.';
    }
    return null;
  }
}

extension on ContactChannel {
  String get label => switch (this) {
    ContactChannel.whatsapp => 'WhatsApp',
    ContactChannel.instagram => 'Instagram',
    ContactChannel.email => 'Correo electrónico',
    ContactChannel.phone => 'Teléfono',
  };

  String get valueLabel => switch (this) {
    ContactChannel.whatsapp => 'Número de WhatsApp',
    ContactChannel.instagram => 'Usuario de Instagram',
    ContactChannel.email => 'Correo electrónico',
    ContactChannel.phone => 'Número de teléfono',
  };

  String get hint => switch (this) {
    ContactChannel.whatsapp => '+593 99 123 4567',
    ContactChannel.instagram => '@usuario',
    ContactChannel.email => 'cliente@correo.com',
    ContactChannel.phone => '+593 2 123 4567',
  };

  TextInputType get keyboardType => switch (this) {
    ContactChannel.email => TextInputType.emailAddress,
    ContactChannel.whatsapp || ContactChannel.phone => TextInputType.phone,
    ContactChannel.instagram => TextInputType.text,
  };

  IconData get icon => switch (this) {
    ContactChannel.whatsapp => Icons.chat_bubble_outline,
    ContactChannel.instagram => Icons.camera_alt_outlined,
    ContactChannel.email => Icons.mail_outline,
    ContactChannel.phone => Icons.phone_outlined,
  };
}

InputDecoration _decoration(
  String label, {
  String? hintText,
  Widget? prefixIcon,
  String? counterText,
}) => InputDecoration(
  labelText: label,
  hintText: hintText,
  prefixIcon: prefixIcon,
  counterText: counterText,
  filled: true,
  fillColor: InkSlotColors.field,
  labelStyle: const TextStyle(color: InkSlotColors.secondary),
  hintStyle: const TextStyle(color: InkSlotColors.tertiary),
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.copper, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.error),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.error, width: 1.5),
  ),
);
