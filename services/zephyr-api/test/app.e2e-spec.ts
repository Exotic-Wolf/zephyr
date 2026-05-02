import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
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
    const hostLoginResponse = await request(app.getHttpServer())
      .post('/v1/auth/guest-login')
      .send({ displayName: 'Host Alpha' })
      .expect(201);

    const hostAccessToken = hostLoginResponse.body.accessToken as string;

    const createdRoomResponse = await request(app.getHttpServer())
      .post('/v1/rooms')
      .set('Authorization', `Bearer ${hostAccessToken}`)
      .send({ title: 'Live Beats Room' })
      .expect(201);

    const viewerLoginResponse = await request(app.getHttpServer())
      .post('/v1/auth/guest-login')
      .send({ displayName: 'Viewer Beta' })
      .expect(201);

    const viewerAccessToken = viewerLoginResponse.body.accessToken as string;

    const liveFeedResponse = await request(app.getHttpServer())
      .get('/v1/feed/live?limit=10')
      .set('Authorization', `Bearer ${viewerAccessToken}`)
      .expect(200);

    expect(Array.isArray(liveFeedResponse.body)).toBe(true);
    expect(liveFeedResponse.body.length).toBeGreaterThan(0);

    const matchingCard = liveFeedResponse.body.find(
      (item: { roomId?: string }) => item.roomId === createdRoomResponse.body.id,
    );

    expect(matchingCard).toBeDefined();
    expect(matchingCard).toEqual(
      expect.objectContaining({
        title: 'Live Beats Room',
        hostDisplayName: 'Host Alpha',
        audienceCount: expect.any(Number),
      }),
    );
  });

  afterEach(async () => {
    await app.close();
  });
});
