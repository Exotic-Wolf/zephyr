import { Body, Controller, Headers, Post } from '@nestjs/common';
import { StoreService } from '../core/store.service';
import { FcmService } from '../core/fcm.service';
import { GuestLoginDto } from './dto/guest-login.dto';
import { GoogleLoginDto } from './dto/google-login.dto';
import { AppleLoginDto } from './dto/apple-login.dto';

@Controller('v1/auth')
export class AuthController {
  constructor(
    private readonly storeService: StoreService,
    private readonly fcmService: FcmService,
  ) {}

  @Post('guest-login')
  async guestLogin(
    @Body() body: GuestLoginDto,
  ): Promise<{ accessToken: string; user: unknown }> {
    return this.storeService.issueGuestSession(body?.displayName);
  }

  @Post('google-login')
  async googleLogin(
    @Body() body: GoogleLoginDto,
  ): Promise<{ accessToken: string; user: unknown }> {
    return this.storeService.issueGoogleSession(body.idToken);
  }

  @Post('apple-login')
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