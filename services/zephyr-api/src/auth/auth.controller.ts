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
    return this.storeService.issueGoogleSession(body.idToken);
  }

  @Post('apple-login')
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  async appleLogin(
    @Body() body: AppleLoginDto,
  ): Promise<{ accessToken: string; user: unknown }> {
    return this.storeService.issueAppleSession(body.idToken, {
      givenName: body.givenName,
      familyName: body.familyName,
      email: body.email,
    });
  }

  @Post('firebase-token')
  async getFirebaseToken(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<{ firebaseToken: string }> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    const token = await this.fcmService.createCustomToken(me.id);
    if (!token) {
      throw new Error('Firebase Admin not initialized');
    }
    return { firebaseToken: token };
  }
}