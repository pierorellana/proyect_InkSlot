export type PublicConfirmationResponse = {
  status: 'confirmed';
  syncStatus: 'pending' | 'synced' | 'failed';
  startAt: string;
  endAt: string;
  timezone: string;
};

export type PublicAppointmentResponse = PublicConfirmationResponse;
