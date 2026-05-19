import * as Sentry from '@sentry/nestjs';

Sentry.init({
  dsn: 'https://2be82e22fe8b3d55251aa7282aa054da@o4511418834354176.ingest.us.sentry.io/4511418869219328',
  tracesSampleRate: 0.2,
});
