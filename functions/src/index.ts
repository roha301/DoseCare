import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import { logger } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';

initializeApp();

const brevoApiKey = defineSecret('BREVO_API_KEY');
const brevoSenderEmail = defineSecret('BREVO_SENDER_EMAIL');

type MailRequest = {
  ownerUid?: string;
  to?: string;
  message?: {
    subject?: string;
    text?: string;
    html?: string;
    attachments?: Array<{
      content?: string;
      filename?: string;
      contentType?: string;
    }>;
  };
};

export const sendDoseCareEmail = onDocumentCreated(
  {
    document: 'mail/{mailId}',
    secrets: [brevoApiKey, brevoSenderEmail],
    region: 'asia-south1',
  },
  async (event) => {
    const data = event.data?.data() as MailRequest | undefined;
    const to = data?.to?.trim();
    const subject = data?.message?.subject?.trim();
    const text = data?.message?.text ?? '';
    const html = data?.message?.html ?? `<p>${text}</p>`;

    if (!to || !subject) {
      logger.warn('Ignoring incomplete DoseCare mail request', { mailId: event.params.mailId });
      return;
    }

    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        accept: 'application/json',
        'api-key': brevoApiKey.value(),
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sender: { name: 'DoseCare', email: brevoSenderEmail.value() },
        to: [{ email: to }],
        subject,
        textContent: text,
        htmlContent: html,
        attachment: data?.message?.attachments?.map((attachment) => ({
          content: attachment.content,
          name: attachment.filename,
          type: attachment.contentType,
        })),
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      logger.error('Brevo rejected DoseCare email', { status: response.status, body });
      throw new Error(`Brevo email failed with HTTP ${response.status}`);
    }
  },
);
