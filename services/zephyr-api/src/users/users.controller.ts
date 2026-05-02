import { Body, Controller, Get, Headers, Patch } from '@nestjs/common';
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
    });
  }
}