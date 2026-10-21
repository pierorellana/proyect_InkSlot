import 'package:flutter/material.dart';

import '../../../../core/widgets/inkslot_kit.dart';
import '../../domain/booking_request_status.dart';

/// Canal de contacto (`.seg`) y dato de contacto (`.fld`).
class ContactChannelField extends StatelessWidget {
  static final _phonePattern = RegExp(r'^\+?[0-9][0-9\s().-]{6,31}$');

  static const _availableChannels = <ContactChannel>[
    ContactChannel.whatsapp,
    ContactChannel.email,
  ];

  const ContactChannelField({
    required this.channel,
    required this.controller,
    required this.onChannelChanged,
    super.key,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  final ContactChannel channel;
  final TextEditingController controller;
  final ValueChanged<ContactChannel> onChannelChanged;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Mensaje de error del dato de contacto, o `null` si es válido.
  static String? validate(ContactChannel channel, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ingresa un dato de contacto.';
    if (channel == ContactChannel.email &&
        (!text.contains('@') || !text.contains('.'))) {
      return 'Revisa el formato del correo.';
    }
    if ((channel == ContactChannel.whatsapp ||
            channel == ContactChannel.phone) &&
        !_phonePattern.hasMatch(text)) {
      return 'Ingresa un número de teléfono válido.';
    }
    if (channel == ContactChannel.instagram && text.length > 64) {
      return 'Usa máximo 64 caracteres.';
    }
    if (channel != ContactChannel.instagram && text.length > 32) {
      return 'Usa máximo 32 caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visibleChannel = _availableChannels.contains(channel)
        ? channel
        : ContactChannel.whatsapp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Canal de contacto',
          child: InkSlotSegmented(
            labels: [for (final value in _availableChannels) value.label],
            selected: _availableChannels.indexOf(visibleChannel),
            onChanged: (index) {
              if (enabled) onChannelChanged(_availableChannels[index]);
            },
          ),
        ),
        const SizedBox(height: 14),
        InkSlotField(
          label: visibleChannel.valueLabel,
          controller: controller,
          hint: visibleChannel.hint,
          keyboardType: visibleChannel.keyboardType,
          textInputAction: TextInputAction.next,
          errorText: errorText,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

extension on ContactChannel {
  String get label => switch (this) {
    ContactChannel.whatsapp => 'WhatsApp',
    ContactChannel.instagram => 'Instagram',
    ContactChannel.email => 'Correo',
    ContactChannel.phone => 'Teléfono',
  };

  String get valueLabel => switch (this) {
    ContactChannel.whatsapp => 'Número de WhatsApp',
    ContactChannel.instagram => 'Usuario de Instagram',
    ContactChannel.email => 'Correo electrónico',
    ContactChannel.phone => 'Número de teléfono',
  };

  String get hint => switch (this) {
    ContactChannel.whatsapp => '+593 …',
    ContactChannel.instagram => '@usuario',
    ContactChannel.email => 'cliente@correo.com',
    ContactChannel.phone => '+593 …',
  };

  TextInputType get keyboardType => switch (this) {
    ContactChannel.email => TextInputType.emailAddress,
    ContactChannel.whatsapp || ContactChannel.phone => TextInputType.phone,
    ContactChannel.instagram => TextInputType.text,
  };
}
