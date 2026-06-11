import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { StoreService } from './../src/core/store.service';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;
  const previousGoogleClientIds = process.env.GOOGLE_CLIENT_IDS;

  beforeEach(async () => {
    process.env.GOOGLE_CLIENT_IDS = 'test-client-id.apps.googleusercontent.com';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('/ (GET)', () => {
    return request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect('Hello World!');
  });

  it('/v1/feed/live (GET) requires auth', () => {
    return request(app.getHttpServer()).get('/v1/feed/live').expect(401);
  });

  it('/v1/feed/live (GET) returns swipe cards for live rooms', async () => {
    const storeService = app.get(StoreService);
    const hostSession = await storeService.issueTestSession('Host Alpha');
    await storeService.updateUser(hostSession.user.id, {
      gender: 'Female',
    });
    const hostAccessToken = hostSession.accessToken;

    const createdRoomResponse = await request(app.getHttpServer())
      .post('/v1/rooms')
      .set('Authorization', `Bearer ${hostAccessToken}`)
      .send({ title: 'Live Beats Room' })
      .expect(201);

    const viewerSession = await storeService.issueTestSession('Viewer Beta');
    const viewerAccessToken = viewerSession.accessToken;

    const liveFeedResponse = await request(app.getHttpServer())
      .get('/v1/feed/live?limit=10')
      .set('Authorization', `Bearer ${viewerAccessToken}`)
      .expect(200);

    expect(Array.isArray(liveFeedResponse.body)).toBe(true);
    expect(liveFeedResponse.body.length).toBeGreaterThan(0);

    const matchingCard = liveFeedResponse.body.find(
      (item: { roomId?: string }) =>
        item.roomId === createdRoomResponse.body.id,
    );

    expect(matchingCard).toBeDefined();
    expect(matchingCard).toEqual(
      expect.objectContaining({
        title: 'Host Alpha',
        hostDisplayName: 'Host Alpha',
        hostStatus: 'live',
        audienceCount: expect.any(Number),
      }),
    );
  });

  it('/v1/auth/logout (POST) revokes the current bearer token', async () => {
    const storeService = app.get(StoreService);
    const session = await storeService.issueTestSession('Viewer Logout');

    await request(app.getHttpServer())
      .post('/v1/auth/logout')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(204);

    await request(app.getHttpServer())
      .get('/v1/users/me')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(401);
  });

  it('/v1/auth/logout (POST) removes push eligibility for the session', async () => {
    const storeService = app.get(StoreService);
    const session = await storeService.issueTestSession('Viewer Push Logout');

    await request(app.getHttpServer())
      .post('/v1/messages/device-token')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ token: 'fcm-token-e2e-logout' })
      .expect(204);

    await expect(
      storeService.getDeviceTokens(session.user.id),
    ).resolves.toEqual(['fcm-token-e2e-logout']);

    await request(app.getHttpServer())
      .post('/v1/auth/logout')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(204);

    await expect(
      storeService.getDeviceTokens(session.user.id),
    ).resolves.toEqual([]);
  });

  it('/v1/auth/google-login (POST) rejects invalid idToken', () => {
    return request(app.getHttpServer())
      .post('/v1/auth/google-login')
      .send({ idToken: 'bogus-token' })
      .expect(401);
  });

  afterEach(async () => {
    await app.close();

    if (previousGoogleClientIds === undefined) {
      delete process.env.GOOGLE_CLIENT_IDS;
    } else {
      process.env.GOOGLE_CLIENT_IDS = previousGoogleClientIds;
    }
  });
});
