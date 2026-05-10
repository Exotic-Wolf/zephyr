import { Body, Controller, Delete, Get, Headers, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { StoreService } from '../core/store.service';
import type { UserProfile } from '../core/store.service';
import { UpdateMeDto } from './dto/update-me.dto';

@Controller('v1/users')
export class UsersController {
  constructor(private readonly storeService: StoreService) {}

  @Get('me')
  async getMe(@Headers('authorization') authorization?: string): Promise<UserProfile> {
    return this.storeService.getUserFromAuthHeader(authorization);
  }

  @Patch('me')
  async updateMe(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: UpdateMeDto,
  ): Promise<UserProfile> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);

    return this.storeService.updateUser(user.id, {
      displayName: body?.displayName,
      avatarUrl: body?.avatarUrl,
      bio: body?.bio,
      gender: body?.gender,
      birthday: body?.birthday,
      countryCode: body?.countryCode,
      language: body?.language,
      callRateCoinsPerMinute: body?.callRateCoinsPerMinute,
    });
  }

  @Get('me/following')
  async getFollowing(@Headers('authorization') authorization?: string): Promise<string[]> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getFollowing(user.id);
  }

  @Get(':userId')
  async getUserById(
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<UserProfile> {
    return this.storeService.getUserById(userId);
  }

  @Post(':userId/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  async followUser(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.followUser(me.id, userId);
  }

  @Delete(':userId/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unfollowUser(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ): Promise<void> {
    const me = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.unfollowUser(me.id, userId);
  }
}