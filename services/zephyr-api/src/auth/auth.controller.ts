import { Body, Controller, Post } from '@nestjs/common';
import { StoreService } from '../core/store.service';
import { GuestLoginDto } from './dto/guest-login.dto';
import { GoogleLoginDto } from './dto/google-login.dto';
import { AppleLoginDto } from './dto/apple-login.dto';

@Controller('v1/auth')
export class AuthController {
  constructor(private readonly storeService: StoreService) {}

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
}