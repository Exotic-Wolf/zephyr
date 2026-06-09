import { Body, Controller, Headers, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { StoreService } from '../core/store.service';
import { FcmService } from '../core/fcm.service';
import { GoogleLoginDto } from './dto/google-login.dto';
import { AppleLoginDto } from './dto/apple-login.dto';

@Controller('v1/auth')
export class AuthController {
  constructor(
    private readonly storeService: StoreService,
    private readonly fcmService: FcmService,
  ) {}

  @Post('google-login')
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  async googleLogin(
    @Body() body: GoogleLoginDto,
  ): Promise<{ accessToken: string; user: unknown }> {
    const session = await this.storeService.issueGoogleSession(body.idToken, {
      deviceId: body.deviceId,
    });
    await this.publishActiveFirebaseSession(session);
    return { accessToken: session.accessToken, user: session.user };
  }

  @Post('apple-login')
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  async appleLogin(
    @Body() body: AppleLoginDto,
  ): Promise<{ accessToken: string; user: unknown }> {
    const session = await this.storeService.issueAppleSession(body.idToken, {
      givenName: body.givenName,
      familyName: body.familyName,
      email: body.email,
      deviceId: body.deviceId,
    });
    await this.publishActiveFirebaseSession(session);
    return { accessToken: session.accessToken, user: session.user };
  }

  @Post('firebase-token')
  async getFirebaseToken(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<{ firebaseToken: string }> {
    const session =
      await this.storeService.getAuthSessionFromAuthHeader(authorization);
    await this.publishActiveFirebaseSession(session);
    const token = await this.fcmService.createCustomToken(session.user.id, {
      sessionId: session.sessionId,
      deviceId: session.deviceId,
    });
    if (!token) {
      throw new Error('Firebase Admin not initialized');
    }
    return { firebaseToken: token };
  }

  private async publishActiveFirebaseSession(session: {
    user: { id: string };
    sessionId: string;
    deviceId: string;
  }): Promise<void> {
    await this.fcmService.setActiveFirebaseSession({
      userId: session.user.id,
      sessionId: session.sessionId,
      deviceId: session.deviceId,
    });
  }
}
